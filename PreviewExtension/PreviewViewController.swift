import Cocoa
import QuickLookUI
import SceneKit
import GLTFKit2
import os.log

private let logger = Logger(subsystem: "jp.0spec.GLTFQuickLook.PreviewExtension", category: "preview")

final class PreviewViewController: NSViewController, QLPreviewingController {
    private var sceneView: SCNView?
    private var securityScopedURL: URL?

    override func loadView() {
        let scnView = SCNView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        scnView.autoresizingMask = [.width, .height]
        scnView.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        sceneView = scnView
        view = scnView
    }

    @objc func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        logger.info("preparePreviewOfFile: \(url.path, privacy: .public)")

        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        GLTFAsset.load(with: url, options: [:]) { [weak self] _, status, asset, error, _ in
            guard let self else { return }
            switch status {
            case .complete:
                guard let asset else {
                    DispatchQueue.main.async { handler(Self.makeError("Asset returned nil")) }
                    return
                }
                let source = GLTFSCNSceneSource(asset: asset)
                guard let scene = source.defaultScene ?? source.scenes.first else {
                    DispatchQueue.main.async { handler(Self.makeError("No scene in asset")) }
                    return
                }
                let animations = source.animations
                DispatchQueue.main.async {
                    self.present(scene: scene, animations: animations)
                    handler(nil)
                }
            case .error:
                logger.error("GLTF load error: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async { handler(error ?? Self.makeError("Unknown load error")) }
            default:
                break
            }
        }
    }

    private func present(scene: SCNScene, animations: [GLTFSCNAnimation]) {
        scene.background.contents = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        addCamera(to: scene)
        sceneView?.scene = scene
        if let first = animations.first {
            scene.rootNode.addAnimationPlayer(first.animationPlayer, forKey: nil)
            first.animationPlayer.animation.repeatCount = .greatestFiniteMagnitude
            first.animationPlayer.play()
        }
    }

    private func addCamera(to scene: SCNScene) {
        let (minVec, maxVec) = scene.rootNode.boundingBox
        let center = SCNVector3((minVec.x + maxVec.x) / 2,
                                (minVec.y + maxVec.y) / 2,
                                (minVec.z + maxVec.z) / 2)
        let extent = max(maxVec.x - minVec.x,
                         max(maxVec.y - minVec.y, maxVec.z - minVec.z))
        let distance = (extent > 0 ? extent : 1) * 2.2

        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.automaticallyAdjustsZRange = true
        camera.wantsHDR = true

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
        cameraNode.look(at: center)
        scene.rootNode.addChildNode(cameraNode)
        sceneView?.pointOfView = cameraNode
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "GLTFQuickLook.Preview", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
