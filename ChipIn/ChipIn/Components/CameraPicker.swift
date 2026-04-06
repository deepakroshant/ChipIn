import SwiftUI
import UIKit

/// Presents the device camera; requires `NSCameraUsageDescription` in Info.plist.
///
/// **Important:** Returning `UIImagePickerController` directly from `UIViewControllerRepresentable`
/// often shows a black / empty preview on real devices. The camera UI expects to be **presented
/// modally**, so we use a tiny container `UIViewController` that presents `UIImagePickerController`
/// full-screen in `viewDidAppear`.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CameraContainerViewController {
        let vc = CameraContainerViewController()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraContainerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.image = img
                    self.parent.dismiss()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.dismiss()
                }
            }
        }
    }

    /// Empty shell that immediately presents the system camera modally (correct lifecycle for preview).
    final class CameraContainerViewController: UIViewController {
        var coordinator: Coordinator?

        private var didPresentCamera = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !didPresentCamera else { return }
            didPresentCamera = true

            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                DispatchQueue.main.async { [weak self] in
                    self?.coordinator?.parent.dismiss()
                }
                return
            }
            guard let coordinator else { return }

            // Next run loop so the fullScreenCover / container has finished laying out.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.cameraDevice = .rear
                picker.delegate = coordinator
                picker.allowsEditing = false
                picker.modalPresentationStyle = .fullScreen
                self.present(picker, animated: true)
            }
        }
    }
}
