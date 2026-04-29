import Foundation
import CoreGraphics
import UIKit
import PencilKit

// MARK: - OneDollarRecognizer
//
// $1 Unistroke Recognizer port pra Swift 5+, baseado em malcommac/SwiftUnistroke
// (MIT License) e algoritmo original Wobbrock/Wilson/Li 2007.
//
// Substitui o algoritmo custom heurístico anterior do PdfShapeSnap. $1 é
// template-matching battle-tested em milhares de apps há 18 anos. Funciona
// com qualquer shape (circle, line, rect, triangle, etc) sem ML, sem SDK
// externa, sem CocoaPods. Puramente geométrico.
//
// Fluxo:
//   1. Resample pra N=64 pontos uniformes
//   2. Rotaciona indicative angle pra origem
//   3. Scale pra 250x250 quadrado
//   4. Translate centroid → (0,0)
//   5. Compara com cada template via path distance no melhor ângulo
//   6. Retorna match com maior similaridade (1.0 = perfeito; threshold 0.78)
//
// Refs:
//   - https://depts.washington.edu/acelab/proj/dollar/
//   - Wobbrock/Wilson/Li (UIST 2007)

struct StrokePoint {
    var x: Double
    var y: Double

    init(x: Double, y: Double) { self.x = x; self.y = y }
    init(_ point: CGPoint) { self.x = Double(point.x); self.y = Double(point.y) }

    static let zero = StrokePoint(x: 0, y: 0)

    func toCGPoint() -> CGPoint { CGPoint(x: x, y: y) }

    func distance(to other: StrokePoint) -> Double {
        let dx = other.x - x, dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }
}

private struct StrokeBoundingBox {
    var x: Double, y: Double, width: Double, height: Double
}

private enum StrokeMath {
    static let phi: Double = 0.5 * (-1.0 + 5.0.squareRoot()) // golden ratio
    static let numPoints: Int = 64
    static let squareSize: Double = 250.0
    static let halfDiagonal: Double = 0.5 * (squareSize * squareSize + squareSize * squareSize).squareRoot()
    static let angleRange: Double = 45.0 * .pi / 180.0
    static let anglePrecision: Double = 2.0 * .pi / 180.0

    static func pathLength(_ points: [StrokePoint]) -> Double {
        var total = 0.0
        for i in 1..<points.count {
            total += points[i - 1].distance(to: points[i])
        }
        return total
    }

    static func pathDistance(_ a: [StrokePoint], _ b: [StrokePoint]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return .infinity }
        var d = 0.0
        for i in 0..<n {
            d += a[i].distance(to: b[i])
        }
        return d / Double(n)
    }

    static func centroid(_ points: [StrokePoint]) -> StrokePoint {
        guard !points.isEmpty else { return .zero }
        var c = StrokePoint.zero
        for p in points { c.x += p.x; c.y += p.y }
        c.x /= Double(points.count)
        c.y /= Double(points.count)
        return c
    }

    static func boundingBox(_ points: [StrokePoint]) -> StrokeBoundingBox {
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return StrokeBoundingBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func resample(_ points: [StrokePoint], totalPoints: Int) -> [StrokePoint] {
        guard points.count >= 2 else { return points }
        let interval = pathLength(points) / Double(totalPoints - 1)
        guard interval > 0 else { return points }
        var working = points
        var newPoints: [StrokePoint] = [points[0]]
        var totalLen = 0.0
        var i = 1
        while i < working.count {
            let prev = working[i - 1]
            let cur = working[i]
            let d = prev.distance(to: cur)
            if (totalLen + d) >= interval {
                let qx = prev.x + ((interval - totalLen) / d) * (cur.x - prev.x)
                let qy = prev.y + ((interval - totalLen) / d) * (cur.y - prev.y)
                let q = StrokePoint(x: qx, y: qy)
                newPoints.append(q)
                working.insert(q, at: i)
                totalLen = 0
            } else {
                totalLen += d
            }
            i += 1
        }
        if newPoints.count == totalPoints - 1, let last = points.last {
            newPoints.append(last)
        }
        return newPoints
    }

    static func indicativeAngle(_ points: [StrokePoint]) -> Double {
        let c = centroid(points)
        guard let first = points.first else { return 0 }
        return atan2(c.y - first.y, c.x - first.x)
    }

    static func rotate(_ points: [StrokePoint], byRadians radians: Double) -> [StrokePoint] {
        let c = centroid(points)
        let cosV = cos(radians), sinV = sin(radians)
        return points.map { p in
            let qx = (p.x - c.x) * cosV - (p.y - c.y) * sinV + c.x
            let qy = (p.x - c.x) * sinV + (p.y - c.y) * cosV + c.y
            return StrokePoint(x: qx, y: qy)
        }
    }

    static func scale(_ points: [StrokePoint], toSize size: Double) -> [StrokePoint] {
        let bbox = boundingBox(points)
        guard bbox.width > 0, bbox.height > 0 else { return points }
        let sx = size / bbox.width, sy = size / bbox.height
        return points.map { StrokePoint(x: $0.x * sx, y: $0.y * sy) }
    }

    static func translate(_ points: [StrokePoint], to target: StrokePoint) -> [StrokePoint] {
        let c = centroid(points)
        return points.map { StrokePoint(x: $0.x + target.x - c.x, y: $0.y + target.y - c.y) }
    }

    static func distanceAtAngle(_ points: [StrokePoint],
                                template: [StrokePoint],
                                radians: Double) -> Double {
        let rotated = rotate(points, byRadians: radians)
        return pathDistance(rotated, template)
    }

    static func distanceAtBestAngle(_ points: [StrokePoint],
                                    template: [StrokePoint],
                                    fromAngle: Double,
                                    toAngle: Double,
                                    threshold: Double) -> Double {
        var fromA = fromAngle, toA = toAngle
        var x1 = phi * fromA + (1 - phi) * toA
        var f1 = distanceAtAngle(points, template: template, radians: x1)
        var x2 = (1 - phi) * fromA + phi * toA
        var f2 = distanceAtAngle(points, template: template, radians: x2)
        while abs(toA - fromA) > threshold {
            if f1 < f2 {
                toA = x2; x2 = x1; f2 = f1
                x1 = phi * fromA + (1 - phi) * toA
                f1 = distanceAtAngle(points, template: template, radians: x1)
            } else {
                fromA = x1; x1 = x2; f1 = f2
                x2 = (1 - phi) * fromA + phi * toA
                f2 = distanceAtAngle(points, template: template, radians: x2)
            }
        }
        return min(f1, f2)
    }
}

// MARK: - Template

struct OneDollarTemplate {
    let name: String
    let normalizedPoints: [StrokePoint]

    init(name: String, rawPoints: [StrokePoint]) {
        self.name = name
        let resampled = StrokeMath.resample(rawPoints, totalPoints: StrokeMath.numPoints)
        let radians = StrokeMath.indicativeAngle(resampled)
        let rotated = StrokeMath.rotate(resampled, byRadians: -radians)
        let scaled = StrokeMath.scale(rotated, toSize: StrokeMath.squareSize)
        let translated = StrokeMath.translate(scaled, to: .zero)
        self.normalizedPoints = translated
    }
}

// MARK: - Recognizer

enum OneDollarError: Error {
    case tooFewPoints
    case noTemplates
    case noMatch
}

enum OneDollarRecognizer {
    /// Roda o algoritmo $1 contra a lista de templates. Retorna o template com
    /// maior similaridade + score 0.0..1.0 (1.0 = perfeito).
    /// Throws se points < 10, templates vazio, ou score < minThreshold.
    static func recognize(rawPoints: [StrokePoint],
                          templates: [OneDollarTemplate],
                          minThreshold: Double = 0.78) throws -> (template: OneDollarTemplate, score: Double) {
        guard !templates.isEmpty else { throw OneDollarError.noTemplates }
        guard rawPoints.count >= 10 else { throw OneDollarError.tooFewPoints }

        let resampled = StrokeMath.resample(rawPoints, totalPoints: StrokeMath.numPoints)
        let radians = StrokeMath.indicativeAngle(resampled)
        let rotated = StrokeMath.rotate(resampled, byRadians: -radians)
        let scaled = StrokeMath.scale(rotated, toSize: StrokeMath.squareSize)
        let translated = StrokeMath.translate(scaled, to: .zero)

        var bestDistance = Double.infinity
        var bestTemplate: OneDollarTemplate?
        for tpl in templates {
            let d = StrokeMath.distanceAtBestAngle(
                translated,
                template: tpl.normalizedPoints,
                fromAngle: -StrokeMath.angleRange,
                toAngle: StrokeMath.angleRange,
                threshold: StrokeMath.anglePrecision
            )
            if d < bestDistance { bestDistance = d; bestTemplate = tpl }
        }
        guard let best = bestTemplate else { throw OneDollarError.noMatch }
        let score = 1.0 - bestDistance / StrokeMath.halfDiagonal
        guard score >= minThreshold else { throw OneDollarError.noMatch }
        return (best, score)
    }
}

// MARK: - Built-in templates: circle, line, rectangle, triangle

enum OneDollarBuiltinTemplates {
    static let all: [OneDollarTemplate] = [
        circle, lineHorizontal, lineVertical, lineDiagonal1, lineDiagonal2,
        rectangle, triangle
    ]

    /// Círculo: 64 pontos em torno de uma circunferência unitária
    static let circle: OneDollarTemplate = {
        var pts: [StrokePoint] = []
        let r = 100.0
        for i in 0..<64 {
            let theta = (Double(i) / 64.0) * 2.0 * .pi
            pts.append(StrokePoint(x: r * cos(theta), y: r * sin(theta)))
        }
        return OneDollarTemplate(name: "circle", rawPoints: pts)
    }()

    /// Linha horizontal: 64 pontos uniformes left → right
    static let lineHorizontal: OneDollarTemplate = {
        let pts = (0..<64).map { i in
            StrokePoint(x: Double(i) * 5.0, y: 0)
        }
        return OneDollarTemplate(name: "line-h", rawPoints: pts)
    }()

    /// Linha vertical: top → bottom
    static let lineVertical: OneDollarTemplate = {
        let pts = (0..<64).map { i in
            StrokePoint(x: 0, y: Double(i) * 5.0)
        }
        return OneDollarTemplate(name: "line-v", rawPoints: pts)
    }()

    /// Linha diagonal /
    static let lineDiagonal1: OneDollarTemplate = {
        let pts = (0..<64).map { i in
            StrokePoint(x: Double(i) * 5.0, y: Double(i) * 5.0)
        }
        return OneDollarTemplate(name: "line-d1", rawPoints: pts)
    }()

    /// Linha diagonal \
    static let lineDiagonal2: OneDollarTemplate = {
        let pts = (0..<64).map { i in
            StrokePoint(x: Double(i) * 5.0, y: Double(63 - i) * 5.0)
        }
        return OneDollarTemplate(name: "line-d2", rawPoints: pts)
    }()

    /// Retângulo: 64 pontos no perímetro de um quadrado
    static let rectangle: OneDollarTemplate = {
        var pts: [StrokePoint] = []
        let side = 100.0
        let perSide = 16
        // Top
        for i in 0..<perSide {
            pts.append(StrokePoint(x: Double(i) * side / Double(perSide), y: 0))
        }
        // Right
        for i in 0..<perSide {
            pts.append(StrokePoint(x: side, y: Double(i) * side / Double(perSide)))
        }
        // Bottom
        for i in 0..<perSide {
            pts.append(StrokePoint(x: side - Double(i) * side / Double(perSide), y: side))
        }
        // Left
        for i in 0..<perSide {
            pts.append(StrokePoint(x: 0, y: side - Double(i) * side / Double(perSide)))
        }
        return OneDollarTemplate(name: "rectangle", rawPoints: pts)
    }()

    /// Triângulo: 64 pontos no perímetro de triângulo equilátero
    static let triangle: OneDollarTemplate = {
        var pts: [StrokePoint] = []
        let r = 100.0
        let perSide = 22
        let a = StrokePoint(x: 0, y: -r)
        let b = StrokePoint(x: r * cos(.pi / 6), y: r * sin(.pi / 6))
        let c = StrokePoint(x: -r * cos(.pi / 6), y: r * sin(.pi / 6))
        for i in 0..<perSide {
            let t = Double(i) / Double(perSide)
            pts.append(StrokePoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        for i in 0..<perSide {
            let t = Double(i) / Double(perSide)
            pts.append(StrokePoint(x: b.x + (c.x - b.x) * t, y: b.y + (c.y - b.y) * t))
        }
        for i in 0..<(64 - 2 * perSide) {
            let t = Double(i) / Double(64 - 2 * perSide)
            pts.append(StrokePoint(x: c.x + (a.x - c.x) * t, y: c.y + (a.y - c.y) * t))
        }
        return OneDollarTemplate(name: "triangle", rawPoints: pts)
    }()
}
