import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("GLTF Quick Look")
                .font(.title)
                .fontWeight(.semibold)
            Text("Provides Quick Look previews and thumbnails\nfor .gltf and .glb 3D model files.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 420, height: 300)
    }
}
