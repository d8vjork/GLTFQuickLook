# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this fork is

This is a **fork of [magicien/GLTFQuickLook](https://github.com/magicien/GLTFQuickLook)** modernized for macOS 26. The upstream was a `.qlgenerator` CFPlugin (deprecated). This fork is a **regular `.app` that ships two App Extensions** — Apple's current way of providing Quick Look previews and thumbnails.

`README.md` is inherited from upstream and describes the old Carthage / `.qlgenerator` workflow. **Ignore it for build/install instructions** — it does not match this fork.

## Project layout

Three Xcode targets in one `.xcodeproj`:

| Target | Path | Role |
|---|---|---|
| `GLTFQuickLook` (app) | `App/` | Host app the user installs. Registers the extensions with macOS via Launch Services. UTIs for `.gltf` / `.glb` are exported from `App/Info.plist`. |
| `GLTFQuickLookExtension` (appex) | `PreviewExtension/` | `QLPreviewingController` for the in-Finder Quick Look preview pane. |
| `GLTFQuickLookThumbnail` (appex) | `ThumbnailExtension/` | `QLThumbnailProvider` for Finder/Spotlight thumbnails. |

Both extensions have `APPLICATION_EXTENSION_API_ONLY = YES`, so any code or dependency they touch must be extension-safe (no `NSApplication`, no `NSWorkspace`, etc.).

The legacy `GLTFQuickLook/` directory (`main.c`, `GeneratePreviewForURL.m`, `Info.plist` with `CFPlugin` keys, …) is the **unused upstream CFPlugin source**. It is *not* in the Xcode project and is not built. Leave it unless explicitly asked to remove it.

## Rendering stack

- Single dependency: **[GLTFKit2](https://github.com/warrenm/GLTFKit2)** via Swift Package Manager (`branch = master`, declared in `project.pbxproj` as an `XCRemoteSwiftPackageReference`). Linked into all three targets. Ships as a binary `xcframework`, so SwiftPM resolution is fast.
- Both extensions follow the same pipeline: `GLTFAsset.load(with: url, options:)` → `GLTFSCNSceneSource(asset:)` → `SCNScene`, then attach a framing camera computed from `scene.rootNode.boundingBox`.
- **Preview** uses a live `SCNView` with `allowsCameraControl` + `autoenablesDefaultLighting` for orbit/zoom.
- **Thumbnail** uses a headless `SCNRenderer` and `snapshot(atTime:with:antialiasingMode:)`, then hands the `CGImage` back via `QLThumbnailReply(contextSize:drawing:)`.
- We do **not** use `ModelIO` / `SCNScene(url:)` for glTF — they don't read `.gltf`/`.glb` on macOS 26. Don't reintroduce them as a "fallback".
- We do **not** use WebKit / Three.js. An earlier attempt bundled Three.js as JS resources served via a `WKURLSchemeHandler`; it was scrapped because it was fragile and required `network.client` / extra entitlements. Don't bring it back.

## Common commands

Build everything (no signing, fastest local check):

```sh
xcodebuild -project GLTFQuickLook.xcodeproj -scheme GLTFQuickLook \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Resolve / refresh the SwiftPM graph after changing `project.pbxproj`:

```sh
xcodebuild -project GLTFQuickLook.xcodeproj -scheme GLTFQuickLook \
  -resolvePackageDependencies
```

Manually exercise the extensions after a signed build (the app must be launched once so Launch Services picks up the embedded `.appex` bundles):

```sh
qlmanage -r              # reload Quick Look generators
qlmanage -p path/to/file.glb   # invoke preview
qlmanage -t path/to/file.glb   # invoke thumbnail
```

Logs from the running extensions (use the subsystem declared in the source):

```sh
log stream --predicate 'subsystem == "jp.0spec.GLTFQuickLook.PreviewExtension"' --style compact
```

There is no test target.

## Editing `project.pbxproj`

The project uses sequential synthetic IDs of the form `AA00xxxx0000000000000000FF`. When adding new build files / file refs / package products, keep the `AA00` prefix and pick an unused 4-hex slot. SwiftPM products are wired through three coordinated entries that must all stay in sync:

1. `XCRemoteSwiftPackageReference` (the repo + version requirement)
2. One `XCSwiftPackageProductDependency` *per consuming target*
3. A `PBXBuildFile` with `productRef = …` per consuming target, listed in that target's `PBXFrameworksBuildPhase`
4. The product dependency ID must also appear in the target's `packageProductDependencies = (...)`, and the package reference ID in the `PBXProject`'s `packageReferences = (...)`.

Forgetting any one of these produces "No such module" at compile time even though `-resolvePackageDependencies` succeeds.

## Bundle identifiers and signing

- App: `jp.0spec.GLTFQuickLook`
- Preview extension: `jp.0spec.GLTFQuickLook.PreviewExtension`
- Thumbnail extension: `jp.0spec.GLTFQuickLook.ThumbnailExtension`
- `DEVELOPMENT_TEAM = 6ZKL3ZKFLP`, automatic signing, hardened runtime on. Debug uses `Apple Development`, Release uses `Developer ID Application` (for notarization-ready distribution).
