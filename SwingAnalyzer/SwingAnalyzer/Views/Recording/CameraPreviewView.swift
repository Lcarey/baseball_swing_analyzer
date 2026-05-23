import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let joints: [String: CGPoint]?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        view.joints = joints
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.session !== session {
            uiView.session = session
        }
        uiView.joints = joints
    }
}

class CameraPreviewUIView: UIView {
    var joints: [String: CGPoint]? {
        didSet {
            updateSkeletonOverlay()
        }
    }

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
            configurePreviewOrientation()
            print("CameraPreviewUIView: Preview layer session assigned")
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    private let skeletonLayer = CAShapeLayer()
    private let jointMarkerLayer = CAShapeLayer()
    private let skeletonConnections: [(String, String)] = [
        (JointName.nose.visionKey, JointName.neck.visionKey),
        (JointName.neck.visionKey, JointName.leftShoulder.visionKey),
        (JointName.neck.visionKey, JointName.rightShoulder.visionKey),
        (JointName.leftShoulder.visionKey, JointName.rightShoulder.visionKey),
        (JointName.leftShoulder.visionKey, JointName.leftElbow.visionKey),
        (JointName.leftElbow.visionKey, JointName.leftWrist.visionKey),
        (JointName.rightShoulder.visionKey, JointName.rightElbow.visionKey),
        (JointName.rightElbow.visionKey, JointName.rightWrist.visionKey),
        (JointName.leftShoulder.visionKey, JointName.leftHip.visionKey),
        (JointName.rightShoulder.visionKey, JointName.rightHip.visionKey),
        (JointName.leftHip.visionKey, JointName.rightHip.visionKey),
        (JointName.leftHip.visionKey, JointName.leftKnee.visionKey),
        (JointName.leftKnee.visionKey, JointName.leftAnkle.visionKey),
        (JointName.rightHip.visionKey, JointName.rightKnee.visionKey),
        (JointName.rightKnee.visionKey, JointName.rightAnkle.visionKey)
    ]
    private let drawableJoints = JointName.allCases.map(\.visionKey)

    override init(frame: CGRect) {
        super.init(frame: frame)
        print("CameraPreviewUIView: Initializing with videoGravity .resizeAspectFill")
        previewLayer.videoGravity = .resizeAspectFill
        configureSkeletonOverlay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        print("CameraPreviewUIView: layoutSubviews called, bounds: \(bounds)")
        previewLayer.frame = bounds
        configurePreviewOrientation()
        skeletonLayer.frame = bounds
        jointMarkerLayer.frame = bounds
        updateSkeletonOverlay()
    }

    private func configurePreviewOrientation() {
        guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else {
            return
        }

        connection.videoOrientation = .portrait
    }

    private func configureSkeletonOverlay() {
        skeletonLayer.fillColor = UIColor.clear.cgColor
        skeletonLayer.strokeColor = UIColor.white.cgColor
        skeletonLayer.lineWidth = 7
        skeletonLayer.lineCap = .round
        skeletonLayer.lineJoin = .round
        skeletonLayer.shadowColor = UIColor.black.cgColor
        skeletonLayer.shadowOpacity = 0.25
        skeletonLayer.shadowRadius = 3
        skeletonLayer.shadowOffset = .zero

        jointMarkerLayer.fillColor = UIColor.white.cgColor
        jointMarkerLayer.strokeColor = UIColor.white.cgColor
        jointMarkerLayer.lineWidth = 1
        jointMarkerLayer.shadowColor = UIColor.black.cgColor
        jointMarkerLayer.shadowOpacity = 0.25
        jointMarkerLayer.shadowRadius = 3
        jointMarkerLayer.shadowOffset = .zero

        previewLayer.addSublayer(skeletonLayer)
        previewLayer.addSublayer(jointMarkerLayer)
    }

    private func updateSkeletonOverlay() {
        guard bounds.width > 0, bounds.height > 0, let joints = joints else {
            clearSkeletonOverlay()
            return
        }

        let convertedJoints = joints.mapValues { point in
            layerPoint(forVisionPoint: point)
        }

        let skeletonPath = UIBezierPath()
        for (startKey, endKey) in skeletonConnections {
            guard let startPoint = convertedJoints[startKey],
                  let endPoint = convertedJoints[endKey] else {
                continue
            }

            skeletonPath.move(to: startPoint)
            skeletonPath.addLine(to: endPoint)
        }

        let markerPath = UIBezierPath()
        for jointKey in drawableJoints {
            guard let point = convertedJoints[jointKey] else { continue }
            let markerRadius: CGFloat = jointKey == JointName.nose.visionKey ? 7 : 6
            markerPath.append(UIBezierPath(
                ovalIn: CGRect(
                    x: point.x - markerRadius,
                    y: point.y - markerRadius,
                    width: markerRadius * 2,
                    height: markerRadius * 2
                )
            ))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        skeletonLayer.path = skeletonPath.cgPath
        jointMarkerLayer.path = markerPath.cgPath
        CATransaction.commit()
    }

    private func clearSkeletonOverlay() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        skeletonLayer.path = nil
        jointMarkerLayer.path = nil
        CATransaction.commit()
    }

    private func layerPoint(forVisionPoint point: CGPoint) -> CGPoint {
        let captureDevicePoint = CGPoint(x: point.x, y: 1 - point.y)
        return previewLayer.layerPointConverted(fromCaptureDevicePoint: captureDevicePoint)
    }
}
