import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            print("CameraPreviewUIView: Session set")
            guard let session = session else {
                print("CameraPreviewUIView: Session is nil")
                return
            }
            print("CameraPreviewUIView: Assigning session to preview layer")
            print("CameraPreviewUIView: Session is running: \(session.isRunning)")
            print("CameraPreviewUIView: Session inputs: \(session.inputs.count)")
            print("CameraPreviewUIView: Session outputs: \(session.outputs.count)")
            previewLayer.session = session
            print("CameraPreviewUIView: Preview layer session assigned")
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        print("CameraPreviewUIView: Initializing with videoGravity .resizeAspectFill")
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        print("CameraPreviewUIView: layoutSubviews called, bounds: \(bounds)")
        previewLayer.frame = bounds
    }
}
