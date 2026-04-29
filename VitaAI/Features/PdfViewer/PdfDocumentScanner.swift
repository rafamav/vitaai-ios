import SwiftUI
import VisionKit

/// SwiftUI wrapper for `VNDocumentCameraViewController` (VisionKit).
///
/// Apple-native document scanner. Detects page edges, corrects perspective,
/// and exports an array of `UIImage`. Used by PdfViewerScreen to scan apostilas,
/// quadros, and handwritten notes directly into the current PDF.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showScanner) {
///     PdfDocumentScanner(
///         onScan: { images in vm.appendScannedPages(images) },
///         onCancel: { showScanner = false }
///     )
/// }
/// ```
struct PdfDocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            // Log + Sentry — antes era silencioso (bug Rafael 2026-04-28).
            NSLog("[PdfDocumentScanner] didFailWithError: %@", error.localizedDescription)
            SentryConfig.capture(error: error, context: ["stage": "document-scanner"])
            VitaPostHogConfig.capture(event: "pdf_scan_failed", properties: [
                "error": error.localizedDescription,
            ])
            onCancel()
        }
    }
}
