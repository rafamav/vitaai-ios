import SwiftUI
import PDFKit
import UIKit

/// Exports an annotated PDF to a new file by flattening all annotation layers.
/// Renders: PDF bitmap + ink strokes + shapes + text annotations → new PDF document.
enum PdfExporter {

    /// Returns a shareable URL for the exported annotated PDF.
    static func export(
        document: PDFDocument,
        pageCount: Int,
        getStrokes: @escaping @Sendable (Int) -> [InkStroke],
        getErasers: @escaping @Sendable (Int) -> [EraserPath],
        getShapes: @escaping @Sendable (Int) -> [ShapeAnnotation],
        getTexts: @escaping @Sendable (Int) -> [TextAnnotation]
    ) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("annotated_\(UUID().uuidString).pdf")

            let renderer = UIGraphicsPDFRenderer(bounds: .zero)
            // Use PDFGraphicsRendererFormat for metadata
            let data = try buildPDFData(
                document: document,
                pageCount: pageCount,
                getStrokes: getStrokes,
                getErasers: getErasers,
                getShapes: getShapes,
                getTexts: getTexts
            )
            try data.write(to: tempURL)
            return tempURL
        }.value
    }

    // MARK: - Private

    private static func buildPDFData(
        document: PDFDocument,
        pageCount: Int,
        getStrokes: (Int) -> [InkStroke],
        getErasers: (Int) -> [EraserPath],
        getShapes: (Int) -> [ShapeAnnotation],
        getTexts: (Int) -> [TextAnnotation]
    ) throws -> Data {
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)

        for pageIndex in 0..<pageCount {
            guard let pdfPage = document.page(at: pageIndex) else { continue }

            // Render at high resolution
            let renderWidth: CGFloat = 1080
            let pageRect = pdfPage.bounds(for: .cropBox)
            let scale = renderWidth / pageRect.width
            let renderSize = CGSize(width: renderWidth, height: pageRect.height * scale)

            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: renderSize), nil)
            guard let ctx = UIGraphicsGetCurrentContext() else { continue }

            // Layer 1: PDF page background
            ctx.saveGState()
            ctx.scaleBy(x: scale, y: scale)
            pdfPage.draw(with: .cropBox, to: ctx)
            ctx.restoreGState()

            // Layer 2: Ink strokes
            let strokes = getStrokes(pageIndex)
            drawStrokes(strokes, in: ctx, scale: scale)

            // Layer 3: Eraser — apply on offscreen then composite (skip for PDF, just skip erased areas)
            // Note: Eraser BlendMode.clear doesn't apply to PDFContext; erased areas remain

            // Layer 4: Shapes
            let shapes = getShapes(pageIndex)
            drawShapes(shapes, in: ctx, scale: scale)

            // Layer 5: Text annotations
            let texts = getTexts(pageIndex)
            drawTexts(texts, in: ctx, scale: scale)
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }

    private static func drawStrokes(_ strokes: [InkStroke], in ctx: CGContext, scale: CGFloat) {
        for stroke in strokes {
            guard stroke.points.count >= 2 else { continue }
            ctx.saveGState()
            let uiColor = UIColor(stroke.color).withAlphaComponent(stroke.alpha)
            ctx.setStrokeColor(uiColor.cgColor)
            ctx.setLineWidth(stroke.width * scale)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: stroke.points[0].x * scale, y: stroke.points[0].y * scale))
            for pt in stroke.points.dropFirst() {
                ctx.addLine(to: CGPoint(x: pt.x * scale, y: pt.y * scale))
            }
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private static func drawShapes(_ shapes: [ShapeAnnotation], in ctx: CGContext, scale: CGFloat) {
        for shape in shapes {
            ctx.saveGState()
            ctx.setStrokeColor(UIColor(shape.color).cgColor)
            ctx.setLineWidth(shape.width * scale)
            ctx.setLineCap(.round)

            let sx = shape.startX * scale, sy = shape.startY * scale
            let ex = shape.endX * scale,   ey = shape.endY * scale

            switch shape.type {
            case .line:
                ctx.move(to: CGPoint(x: sx, y: sy))
                ctx.addLine(to: CGPoint(x: ex, y: ey))
                ctx.strokePath()

            case .arrow:
                ctx.move(to: CGPoint(x: sx, y: sy))
                ctx.addLine(to: CGPoint(x: ex, y: ey))
                ctx.strokePath()
                // Arrow head
                let arrowLen = shape.width * 4 * scale
                let angle = atan2(ey - sy, ex - sx)
                let a1 = angle + .pi * 5 / 6
                let a2 = angle - .pi * 5 / 6
                ctx.move(to: CGPoint(x: ex, y: ey))
                ctx.addLine(to: CGPoint(x: ex + arrowLen * cos(a1), y: ey + arrowLen * sin(a1)))
                ctx.move(to: CGPoint(x: ex, y: ey))
                ctx.addLine(to: CGPoint(x: ex + arrowLen * cos(a2), y: ey + arrowLen * sin(a2)))
                ctx.strokePath()

            case .rectangle:
                let rect = CGRect(
                    x: min(sx, ex), y: min(sy, ey),
                    width: abs(ex - sx), height: abs(ey - sy)
                )
                if shape.filled {
                    ctx.setFillColor(UIColor(shape.color).withAlphaComponent(0.3).cgColor)
                    ctx.fill(rect)
                }
                ctx.stroke(rect)

            case .circle:
                let cx = (sx + ex) / 2, cy = (sy + ey) / 2
                let rx = abs(ex - sx) / 2, ry = abs(ey - sy) / 2
                let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                if shape.filled {
                    ctx.setFillColor(UIColor(shape.color).withAlphaComponent(0.3).cgColor)
                    ctx.fillEllipse(in: rect)
                }
                ctx.strokeEllipse(in: rect)
            }
            ctx.restoreGState()
        }
    }

    private static func drawTexts(_ texts: [TextAnnotation], in ctx: CGContext, scale: CGFloat) {
        for text in texts {
            guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: text.fontSize * scale),
                .foregroundColor: UIColor(text.color)
            ]
            (text.text as NSString).draw(
                at: CGPoint(x: text.x * scale, y: text.y * scale),
                withAttributes: attrs
            )
        }
    }
}
