import QuickLookThumbnailing
import SceneKit
import GLTFKit2
import Metal
import AppKit

final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let url = request.fileURL
        let size = request.maximumSize
        let scale = request.scale

        let scoped = url.startAccessingSecurityScopedResource()

        GLTFAsset.load(with: url, options: [:]) { _, status, asset, error, _ in
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            switch status {
            case .complete:
                guard let asset,
                      let device = MTLCreateSystemDefaultDevice() else {
                    handler(nil, Self.makeError("Metal device unavailable"))
                    return
                }
                let source = GLTFSCNSceneSource(asset: asset)
                guard let scene = source.defaultScene ?? source.scenes.first else {
                    handler(nil, Self.makeError("No scene in asset"))
                    return
                }

                let cameraNode = Self.makeCamera(for: scene)
                scene.rootNode.addChildNode(cameraNode)

                let renderer = SCNRenderer(device: device, options: nil)
                renderer.scene = scene
                renderer.pointOfView = cameraNode
                renderer.autoenablesDefaultLighting = true

                let pixelSize = CGSize(width: size.width * scale,
                                       height: size.height * scale)
                let image = renderer.snapshot(atTime: 0,
                                              with: pixelSize,
                                              antialiasingMode: .multisampling4X)

                let reply = QLThumbnailReply(contextSize: size) { context -> Bool in
                    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        return false
                    }
                    context.draw(cg, in: CGRect(origin: .zero, size: size))
                    return true
                }
                handler(reply, nil)

            case .error:
                handler(nil, error ?? Self.makeError("Unknown load error"))
            default:
                break
            }
        }
    }

    private static func makeCamera(for scene: SCNScene) -> SCNNode {
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

        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(center.x, center.y, center.z + distance)
        node.look(at: center)
        return node
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "GLTFQuickLook.Thumbnail", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
