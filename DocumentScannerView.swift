import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onTextRecognized: (String) -> Void
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized, onError: onError)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onTextRecognized: (String) -> Void
        let onError: (String) -> Void

        init(onTextRecognized: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onTextRecognized = onTextRecognized
            self.onError = onError
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)

            Task {
                do {
                    var pages: [String] = []

                    for pageIndex in 0..<scan.pageCount {
                        let image = scan.imageOfPage(at: pageIndex)
                        let text = try await OCRService.shared.recognizeText(from: image)

                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            pages.append(text)
                        }
                    }

                    await MainActor.run {
                        onTextRecognized(pages.joined(separator: "\n\n"))
                    }
                } catch {
                    await MainActor.run {
                        onError(error.localizedDescription)
                    }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            onError(error.localizedDescription)
        }
    }
}
