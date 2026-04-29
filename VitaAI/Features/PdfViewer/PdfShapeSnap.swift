import Foundation
import PencilKit
import CoreGraphics

// MARK: - PdfShapeSnap (refeito 2026-04-29 com $1 Recognizer)
//
// Detector de shapes (circle, line, rectangle, triangle) baseado no algoritmo
// $1 Unistroke Recognizer (Wobbrock/Wilson/Li 2007). Substitui o algoritmo
// custom heurístico anterior que não funcionava de forma confiável.
//
// Como funciona:
//   1. Stroke do user é recolhido via PKStrokePath → [ODPoint]
//   2. Guards anti-letra (mínimo de pontos, duração, tamanho) — apertados o
//      bastante pra não pegar handwriting, soltos o bastante pra pegar shape
//      apressado normal.
//   3. OneDollarRecognizer compara o stroke contra templates (circle, line-h,
//      line-v, line-d1, line-d2, rectangle, triangle).
//   4. Se score >= 0.78 (threshold), retorna o shape detectado + parâmetros
//      geométricos calculados do bbox/centroid do stroke ORIGINAL (não do
//      template normalizado).
//
// Refs:
//   - https://depts.washington.edu/acelab/proj/dollar/
//   - OneDollarRecognizer.swift (port de malcommac/SwiftUnistroke, MIT)

enum PdfShapeSnap {

    /// Resultado da detecção. Parâmetros (start/end, center/radius, rect)
    /// são calculados a partir do bbox do stroke ORIGINAL pra preservar
    /// posição na página.
    enum Result {
        case none
        case line(start: CGPoint, end: CGPoint)
        case circle(center: CGPoint, radius: CGFloat)
        case rectangle(rect: CGRect)
    }

    /// Telemetria PostHog. Mantém compatibilidade com call site existente.
    enum DetectOutcome {
        case appliedLine(confidence: CGFloat)
        case appliedCircle(confidence: CGFloat)
        case appliedRectangle(confidence: CGFloat)
        case rejectedTooShort
        case rejectedTooSmall
        case rejectedTooFewPoints
        case rejectedNoMatch
    }

    struct Config {
        /// Mínimo de pontos. Com $1 e resample=64, qualquer stroke >=10 funciona,
        /// mas exigimos 12 pra anti-micro-stroke.
        var minPoints: Int = 12
        /// Duração mínima. Letras são <0.15s; shape intencional >0.15s.
        var minStrokeDuration: TimeInterval = 0.15
        /// Tamanho mínimo do bbox. Letras <40pt, shape >=40pt.
        var minBboxSize: CGFloat = 40
        /// Threshold $1 (0..1, 1=perfeito). 0.78 = padrão paper Wobbrock.
        var minScore: Double = 0.78

        static let `default` = Config()
    }

    /// Detect roda em mainthread no callback do PencilKit. Stroke é o último
    /// stroke do PKDrawing.
    static func detect(stroke: PKStroke, config: Config = .default) -> (Result, DetectOutcome) {
        // 1. Extrai pontos do stroke
        var rawPoints: [StrokePoke] = []
        var firstTime: TimeInterval = 0
        var lastTime: TimeInterval = 0
        var idx = 0
        let path = stroke.path
        for pathIndex in path.indices {
            let p = path[pathIndex]
            if idx == 0 { firstTime = p.timeOffset }
            lastTime = p.timeOffset
            rawPoints.append(StrokePoke(point: ODPoint(p.location), time: p.timeOffset))
            idx += 1
        }

        // 2. Guards
        guard rawPoints.count >= config.minPoints else {
            return (.none, .rejectedTooFewPoints)
        }
        let duration = lastTime - firstTime
        guard duration >= config.minStrokeDuration else {
            return (.none, .rejectedTooShort)
        }
        let bbox = computeBoundingBox(rawPoints.map { $0.point.toCGPoint() })
        guard max(bbox.width, bbox.height) >= config.minBboxSize else {
            return (.none, .rejectedTooSmall)
        }

        // 3. Roda $1 Recognizer
        let strokePoints = rawPoints.map { $0.point }
        let match: (template: OneDollarTemplate, score: Double)
        do {
            match = try OneDollarRecognizer.recognize(
                rawPoints: strokePoints,
                templates: OneDollarBuiltinTemplates.all,
                minThreshold: config.minScore
            )
        } catch {
            return (.none, .rejectedNoMatch)
        }

        // 4. Constrói Result a partir do nome do template + bbox original
        let confidence = CGFloat(match.score)
        switch match.template.name {
        case "circle":
            let center = CGPoint(x: bbox.midX, y: bbox.midY)
            let radius = max(bbox.width, bbox.height) / 2.0
            return (.circle(center: center, radius: radius), .appliedCircle(confidence: confidence))

        case "line-h", "line-v", "line-d1", "line-d2":
            // Pega ponto mais distante do início como end
            let cgPoints = rawPoints.map { $0.point.toCGPoint() }
            guard let first = cgPoints.first, let last = cgPoints.last else {
                return (.none, .rejectedNoMatch)
            }
            return (.line(start: first, end: last), .appliedLine(confidence: confidence))

        case "rectangle":
            return (.rectangle(rect: bbox), .appliedRectangle(confidence: confidence))

        case "triangle":
            // Triângulo: trata como nada por enquanto (não temos replacement geométrico).
            // Adicionar futuramente shape annotation triangular.
            return (.none, .rejectedNoMatch)

        default:
            return (.none, .rejectedNoMatch)
        }
    }

    /// Constrói PKStroke replacement com base no Result detectado.
    /// Mantém ink/cor/largura do stroke original.
    static func makeReplacementStroke(for result: Result, ink: PKInk) -> PKStroke? {
        switch result {
        case .none:
            return nil

        case .line(let start, let end):
            let path = PKStrokePath(controlPoints: [
                PKStrokePoint(location: start, timeOffset: 0,
                              size: CGSize(width: 4, height: 4),
                              opacity: 1, force: 1, azimuth: 0, altitude: 0),
                PKStrokePoint(location: end, timeOffset: 0.05,
                              size: CGSize(width: 4, height: 4),
                              opacity: 1, force: 1, azimuth: 0, altitude: 0),
            ], creationDate: Date())
            return PKStroke(ink: ink, path: path)

        case .circle(let center, let radius):
            var pts: [PKStrokePoint] = []
            let n = 64
            for i in 0...n {
                let theta = (Double(i) / Double(n)) * 2.0 * .pi
                let x = center.x + CGFloat(cos(theta)) * radius
                let y = center.y + CGFloat(sin(theta)) * radius
                pts.append(PKStrokePoint(
                    location: CGPoint(x: x, y: y),
                    timeOffset: TimeInterval(i) * 0.001,
                    size: CGSize(width: 4, height: 4),
                    opacity: 1, force: 1, azimuth: 0, altitude: 0
                ))
            }
            let path = PKStrokePath(controlPoints: pts, creationDate: Date())
            return PKStroke(ink: ink, path: path)

        case .rectangle(let rect):
            // 4 cantos
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY), // close
            ]
            let pts = corners.enumerated().map { (i, p) in
                PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01,
                              size: CGSize(width: 4, height: 4),
                              opacity: 1, force: 1, azimuth: 0, altitude: 0)
            }
            let path = PKStrokePath(controlPoints: pts, creationDate: Date())
            return PKStroke(ink: ink, path: path)
        }
    }

    // MARK: - Helpers

    private static func computeBoundingBox(_ points: [CGPoint]) -> CGRect {
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// Wrapper interno pra carry timestamp + point juntos durante guards.
private struct StrokePoke {
    let point: ODPoint
    let time: TimeInterval
}
