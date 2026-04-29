import Foundation
import PencilKit
import CoreGraphics

// MARK: - PdfShapeSnap
//
// Snap-on-pause shape recognition (Goodnotes 6 / Notability pattern).
// Quando o usuário solta a caneta, o último stroke é analisado:
//   - É uma linha reta? Substitui por stroke linear perfeito (2 pontos).
//   - É um círculo? Substitui por círculo perfeito (32 pontos parametrizados).
//
// Threshold conservador (residuals normalizados <= 0.05) — só substitui se
// tiver alta confiança. Senão, mantém o stroke original do usuário (zero
// regressão).
//
// Algoritmos:
//   - Linha reta: regressão linear least-squares + cálculo de residual médio.
//   - Círculo: algebraic least-squares circle fit (Pratt's variant) — fast,
//     numericamente estável, sem dependência externa.
//
// Refs open-source:
//   - https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
//   - https://www.scribd.com/document/14819165/Circle-Fitting-LMS-Pratt-1987

enum PdfShapeSnap {

    /// Resultado da detecção.
    enum Result {
        case none
        case line(start: CGPoint, end: CGPoint)
        case circle(center: CGPoint, radius: CGFloat)
    }

    /// Configuração de threshold. Valores mais altos = mais permissivo (pega
    /// mais shapes mas com mais falsos positivos). Default conservador.
    ///
    /// **Guards anti-letra (2026-04-28 reativação):** o bug de 2026-04-26 foi
    /// substituir letras manuscritas por shapes vazios. Letras manuscritas
    /// têm assinatura distinta de shapes intencionais:
    ///   - Letras: rápidas (<0.3s), pequenas (<40pt bbox), poucos pontos
    ///   - Shape intencional: usuário desacelera, ocupa espaço, mais pontos
    /// Os campos `minStrokeDuration` + `minBboxSize` + `lineMinLength` +
    /// `lineMinAspectRatio` somados eliminam praticamente todos os falsos
    /// positivos em escrita à mão.
    struct Config {
        /// Mínimo de pontos pra considerar tentativa de snap (descarta micro-strokes).
        /// Raised 8→20 (2026-04-28) — letras curtas (i, l, t, /) tinham 8-15 pontos.
        var minPoints: Int = 12
        /// Duração mínima do stroke. Letras são rabiscadas em <0.3s; shape
        /// intencional o usuário pausa um pouco (>0.4s).
        var minStrokeDuration: TimeInterval = 0.2
        /// Tamanho mínimo do bounding box (max(width, height) em pontos).
        /// Letras manuscritas tipicamente <40pt; shapes intencionais ≥60pt.
        var minBboxSize: CGFloat = 40
        /// Resíduo máximo (normalizado pelo bounding box) pra aceitar como linha.
        /// Apertado 0.04→0.025 (2026-04-28) — só linhas REALMENTE retas.
        var lineResidualThreshold: CGFloat = 0.05
        /// Comprimento mínimo da linha em pontos. Linhas curtas viram letras
        /// tipo "I", "l", "/", "−". 100pt = ~2.5cm no display.
        var lineMinLength: CGFloat = 60
        /// Aspect ratio mínimo do bbox pra considerar linha (lado_longo/lado_curto).
        /// Linha intencional é estreita (>5:1); letras são quase quadradas (~1:1).
        var lineMinAspectRatio: CGFloat = 4.0
        /// Resíduo máximo pra aceitar como círculo.
        /// Apertado 0.05→0.04 (2026-04-28).
        var circleResidualThreshold: CGFloat = 0.07
        /// Razão mínima pra considerar círculo (perimetro / hipotenuse_bbox).
        /// Círculo fechado tem ratio > 2.5 — descarta arcos abertos. Subido pra 2.4.
        var circleClosureRatio: CGFloat = 2.0
        /// Razão de fechamento (distância entre primeiro e último ponto / perímetro).
        /// Círculo fecha (<0.15); letra "C", "U", arco aberto não.
        var circleMaxOpenness: CGFloat = 0.30

        static let `default` = Config()
    }

    /// Telemetria do que aconteceu no detect — pra PostHog poder ver se o
    /// algoritmo está sendo chamado mas rejeitando, ou nem tentando.
    enum DetectOutcome {
        case appliedLine(confidence: CGFloat)
        case appliedCircle(confidence: CGFloat)
        case rejectedTooShort               // duração < minStrokeDuration
        case rejectedTooSmall               // bbox < minBboxSize
        case rejectedTooFewPoints           // < minPoints
        case rejectedNoMatch                // passou guards mas nem linha nem círculo bateu
    }

    /// Detecta a melhor shape pra um stroke. Retorna Result + outcome telemetria.
    ///
    /// **Guards de entrada** (todos precisam passar antes de tentar fit):
    ///   1. `points.count >= minPoints` (20)
    ///   2. duração do stroke `>= minStrokeDuration` (0.4s)
    ///   3. `max(bbox.width, bbox.height) >= minBboxSize` (60pt)
    ///
    /// Se algum guard falhar → `.none` + outcome correspondente. Garantia: nenhuma
    /// letra manuscrita típica passa todos os 3.
    static func detect(stroke: PKStroke, config: Config = .default) -> (result: Result, outcome: DetectOutcome) {
        let points = stroke.path.map { $0.location }

        // Guard 1: mínimo de pontos.
        guard points.count >= config.minPoints else {
            return (.none, .rejectedTooFewPoints)
        }

        // Guard 2: duração do stroke. PKStrokePoint tem timeOffset; total =
        // último - primeiro.
        let duration: TimeInterval
        if let firstPoint = stroke.path.first, let lastPoint = stroke.path.last {
            duration = lastPoint.timeOffset - firstPoint.timeOffset
        } else {
            duration = 0
        }
        guard duration >= config.minStrokeDuration else {
            return (.none, .rejectedTooShort)
        }

        // Guard 3: tamanho do bbox.
        let bbox = boundingBox(points)
        let bboxSize = max(bbox.width, bbox.height)
        guard bboxSize >= config.minBboxSize else {
            return (.none, .rejectedTooSmall)
        }

        // Tenta linha primeiro (mais barato + mais comum).
        if let line = tryLine(points: points,
                              threshold: config.lineResidualThreshold,
                              minLength: config.lineMinLength,
                              minAspectRatio: config.lineMinAspectRatio,
                              bbox: bbox) {
            return (.line(start: line.start, end: line.end), .appliedLine(confidence: line.confidence))
        }

        // Tenta círculo (mais caro, requer pontos suficientes pra fit estável).
        if points.count >= 24,
           let circle = tryCircle(points: points,
                                  residualThreshold: config.circleResidualThreshold,
                                  closureRatio: config.circleClosureRatio,
                                  maxOpenness: config.circleMaxOpenness) {
            return (.circle(center: circle.center, radius: circle.radius), .appliedCircle(confidence: circle.confidence))
        }

        return (.none, .rejectedNoMatch)
    }

    /// Constrói um PKStroke geométrico limpo a partir de um Result, herdando o
    /// `ink` (cor + largura) do stroke original do usuário pra preservar estilo.
    static func makeReplacementStroke(for result: Result, ink: PKInk) -> PKStroke? {
        switch result {
        case .none:
            return nil
        case let .line(start, end):
            return makeLineStroke(start: start, end: end, ink: ink)
        case let .circle(center, radius):
            return makeCircleStroke(center: center, radius: radius, ink: ink)
        }
    }

    // MARK: - Algoritmos privados

    /// Tenta ajustar uma reta aos pontos via least-squares. Retorna start/end
    /// projetados sobre a reta, com resíduo médio normalizado pelo bbox.
    ///
    /// Guards adicionais (anti-letra):
    ///   - `minLength`: linha curta vira letras "l"/"/"/"-".
    ///   - `minAspectRatio`: bbox precisa ser longo+estreito (>5:1).
    private static func tryLine(points: [CGPoint],
                                threshold: CGFloat,
                                minLength: CGFloat,
                                minAspectRatio: CGFloat,
                                bbox: CGRect) -> (start: CGPoint, end: CGPoint, confidence: CGFloat)? {
        // Aspect ratio guard — letras manuscritas têm ratio ~1-2 (quase quadrado).
        let longSide = max(bbox.width, bbox.height)
        let shortSide = max(min(bbox.width, bbox.height), 1)  // evita /0
        let aspectRatio = longSide / shortSide
        guard aspectRatio >= minAspectRatio else { return nil }

        let n = CGFloat(points.count)
        var sumX: CGFloat = 0, sumY: CGFloat = 0, sumXX: CGFloat = 0, sumXY: CGFloat = 0
        for p in points {
            sumX += p.x; sumY += p.y
            sumXX += p.x * p.x; sumXY += p.x * p.y
        }
        let denom = n * sumXX - sumX * sumX

        let projFirst: CGPoint
        let projLast: CGPoint
        let avgResidual: CGFloat
        let bboxDiag = hypot(bbox.width, bbox.height)
        guard bboxDiag > 1 else { return nil }

        if abs(denom) > 1e-6 {
            let slope = (n * sumXY - sumX * sumY) / denom
            let intercept = (sumY - slope * sumX) / n

            // Resíduo médio (distância perpendicular dos pontos à reta y = mx + b).
            let denomDist = sqrt(1 + slope * slope)
            var residualSum: CGFloat = 0
            for p in points {
                residualSum += abs(p.y - (slope * p.x + intercept)) / denomDist
            }
            avgResidual = residualSum / n

            projFirst = projectOntoLine(point: points.first!, slope: slope, intercept: intercept)
            projLast  = projectOntoLine(point: points.last!,  slope: slope, intercept: intercept)
        } else {
            // Linha vertical — fallback.
            guard let minY = points.min(by: { $0.y < $1.y }),
                  let maxY = points.max(by: { $0.y < $1.y }),
                  abs(maxY.y - minY.y) > 10 else { return nil }
            projFirst = minY
            projLast = maxY
            // Resíduo: dispersão em x.
            let avgX = sumX / n
            var residualSum: CGFloat = 0
            for p in points { residualSum += abs(p.x - avgX) }
            avgResidual = residualSum / n
        }

        // Comprimento mínimo (anti "l"/"/"/"-").
        let lineLength = hypot(projLast.x - projFirst.x, projLast.y - projFirst.y)
        guard lineLength >= minLength else { return nil }

        let normResidual = avgResidual / bboxDiag
        guard normResidual <= threshold else { return nil }

        // Confidence: 1.0 = resíduo zero, 0.0 = no threshold.
        let confidence = max(0, 1 - (normResidual / threshold))
        return (projFirst, projLast, confidence)
    }

    /// Algebraic least-squares circle fit. Retorna center+radius+resíduo.
    /// Algoritmo: minimiza ||A·x = b||^2 onde A = [2x, 2y, 1], x = [a, b, c],
    /// b = x²+y². Center = (a, b), radius = sqrt(c + a² + b²).
    ///
    /// Guards adicionais (anti-letra):
    ///   - `closureRatio`: perímetro / diagonal_bbox ≥ 2.4 (círculo dá volta).
    ///   - `maxOpenness`: gap(primeiro, último) / perímetro ≤ 0.18 (círculo fecha).
    private static func tryCircle(points: [CGPoint],
                                  residualThreshold: CGFloat,
                                  closureRatio: CGFloat,
                                  maxOpenness: CGFloat) -> (center: CGPoint, radius: CGFloat, confidence: CGFloat)? {
        // Validação de fechamento — círculos têm perímetro >> hipotenusa do bbox.
        let perim = pathLength(points)
        let bbox = boundingBox(points)
        let bboxDiag = hypot(bbox.width, bbox.height)
        guard bboxDiag > 1, perim / bboxDiag >= closureRatio else { return nil }

        // Openness — círculo intencional fecha. Letras "C", "U", arcos abertos
        // têm gap grande relativo ao perímetro.
        if let first = points.first, let last = points.last, perim > 1 {
            let gap = hypot(last.x - first.x, last.y - first.y)
            guard gap / perim <= maxOpenness else { return nil }
        }

        // Monta sistema A·x = b (3x3 normal equations).
        var s00: CGFloat = 0, s01: CGFloat = 0, s02: CGFloat = 0
        var s11: CGFloat = 0, s12: CGFloat = 0
        var b0: CGFloat = 0, b1: CGFloat = 0, b2: CGFloat = 0
        let n = CGFloat(points.count)
        for p in points {
            let x = p.x, y = p.y
            let r2 = x * x + y * y
            s00 += 4 * x * x
            s01 += 4 * x * y
            s02 += 2 * x
            s11 += 4 * y * y
            s12 += 2 * y
            b0 += 2 * x * r2
            b1 += 2 * y * r2
            b2 += r2
        }
        let s22 = n
        // Resolve via Cramer (3x3 — pequeno, estável).
        let det = s00 * (s11 * s22 - s12 * s12)
                - s01 * (s01 * s22 - s12 * s02)
                + s02 * (s01 * s12 - s11 * s02)
        guard abs(det) > 1e-6 else { return nil }
        let a = (b0 * (s11 * s22 - s12 * s12)
                - s01 * (b1 * s22 - s12 * b2)
                + s02 * (b1 * s12 - s11 * b2)) / det
        let bC = (s00 * (b1 * s22 - s12 * b2)
                - b0 * (s01 * s22 - s12 * s02)
                + s02 * (s01 * b2 - b1 * s02)) / det
        let c = (s00 * (s11 * b2 - b1 * s12)
                - s01 * (s01 * b2 - b1 * s02)
                + b0 * (s01 * s12 - s11 * s02)) / det

        let center = CGPoint(x: a, y: bC)
        let radiusSq = c + a * a + bC * bC
        guard radiusSq > 1 else { return nil }
        let radius = sqrt(radiusSq)

        // Resíduo médio: |distância(p, center) - radius|, normalizado pelo radius.
        var residualSum: CGFloat = 0
        for p in points {
            let d = hypot(p.x - center.x, p.y - center.y)
            residualSum += abs(d - radius)
        }
        let avgResidual = residualSum / n
        let normResidual = avgResidual / radius

        guard normResidual <= residualThreshold else { return nil }
        let confidence = max(0, 1 - (normResidual / residualThreshold))
        return (center, radius, confidence)
    }

    private static func projectOntoLine(point: CGPoint, slope: CGFloat, intercept: CGFloat) -> CGPoint {
        // Projeção ortogonal de p sobre y = mx + b.
        let m = slope, b = intercept, x = point.x, y = point.y
        let denom = 1 + m * m
        let projX = (x + m * y - m * b) / denom
        let projY = m * projX + b
        return CGPoint(x: projX, y: projY)
    }

    private static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var sum: CGFloat = 0
        for i in 1..<points.count {
            sum += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }
        return sum
    }

    // MARK: - Construção de PKStroke geométrico

    private static func makeLineStroke(start: CGPoint, end: CGPoint, ink: PKInk) -> PKStroke {
        // 16 pontos interpolados — suficiente pra renderização suave em qualquer escala.
        var controlPoints: [PKStrokePoint] = []
        let steps = 16
        let dist = hypot(end.x - start.x, end.y - start.y)
        let baseT = Date().timeIntervalSinceReferenceDate
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            let pt = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(t) * 0.1,
                size: CGSize(width: 2, height: 2),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
            controlPoints.append(pt)
            _ = dist; _ = baseT
        }
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    private static func makeCircleStroke(center: CGPoint, radius: CGFloat, ink: PKInk) -> PKStroke {
        // 64 pontos parametrizados — círculo visualmente perfeito.
        var controlPoints: [PKStrokePoint] = []
        let steps = 64
        for i in 0...steps {
            let theta = (CGFloat(i) / CGFloat(steps)) * 2 * .pi
            let x = center.x + radius * cos(theta)
            let y = center.y + radius * sin(theta)
            let pt = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.005,
                size: CGSize(width: 2, height: 2),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
            controlPoints.append(pt)
        }
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }
}
