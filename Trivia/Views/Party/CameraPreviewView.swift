import SwiftUI
import AVFoundation

/// Wraps AVCaptureVideoPreviewLayer in a SwiftUI view.
struct CameraPreviewView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            layer.frame = uiView.bounds
        }
    }
}
