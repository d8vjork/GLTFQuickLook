# GLTFQuickLook

macOS Quick Look support for glTF (`.gltf`) and glTF Binary (`.glb`) files — preview them by pressing Space in Finder, and get rendered thumbnails in Finder/Spotlight.

A modernized rewrite of [magicien/GLTFQuickLook](https://github.com/magicien/GLTFQuickLook), updated for macOS 26. The original was a `.qlgenerator` CFPlugin (Apple deprecated that mechanism); this version is a regular app that ships two App Extensions, which is the supported way to provide Quick Look on current macOS.

![Preview](screenshot.png)
![Preview animated](screenshot2.gif)

## Requirements

- macOS 12 (Monterey) or later. Tested on macOS 26.
- Apple Silicon or Intel.

## Install

1. Download the latest **`GLTFQuickLook.dmg`** from the [Releases page](https://github.com/d8vjork/GLTFQuickLook/releases/latest).
2. Open the DMG and drag **GLTFQuickLook.app** into the **Applications** folder.
3. Launch **GLTFQuickLook** once. macOS registers the embedded Quick Look extensions on first launch — after that you can quit the app, it does not need to keep running.
4. In Finder, select a `.glb` or `.gltf` file and press **Space**. You should see an interactive 3D preview (drag to orbit, scroll to zoom).

If thumbnails or previews do not refresh immediately, run:

```sh
qlmanage -r && qlmanage -r cache && killall Finder
```

The release build is signed with a Developer ID and notarized by Apple, so Gatekeeper will accept it without any `xattr` workaround.

### Uninstall

Drag `GLTFQuickLook.app` from `/Applications` to the Trash, then run `qlmanage -r`.

## Build from source

Requirements: Xcode 15 or later.

```sh
git clone https://github.com/d8vjork/GLTFQuickLook.git
cd GLTFQuickLook
make install
```

`make install` does a Debug build, copies the resulting `.app` to `~/Applications/GLTFQuickLook.app`, registers the extensions with Launch Services, and refreshes Quick Look. After that, Space-preview a `.glb` to verify.

Other useful targets (`make help` for the full list):

| Target | What it does |
|---|---|
| `make build` | Build only (no install) |
| `make rebuild` | `clean` + `install` |
| `make reinstall` | Wipe the installed copy first, then `install` |
| `make reload` | Re-register the installed bundle and refresh Quick Look (no rebuild) |
| `make uninstall` | Unregister and delete from `~/Applications` |
| `make clean` | `xcodebuild clean` and `rm -rf build/` |

The single dependency is [GLTFKit2](https://github.com/warrenm/GLTFKit2), pulled in via Swift Package Manager — Xcode resolves it automatically on first build.

## Architecture

Three Xcode targets:

- **GLTFQuickLook** (`App/`) — host app the user installs. Exports the `org.khronos.gltf` / `org.khronos.glb` UTIs and embeds the two extensions.
- **GLTFQuickLookExtension** (`PreviewExtension/`) — `QLPreviewingController` providing the in-Finder Quick Look preview pane. Uses `SCNView` with `allowsCameraControl` for orbit/zoom.
- **GLTFQuickLookThumbnail** (`ThumbnailExtension/`) — `QLThumbnailProvider` rendering thumbnails for Finder and Spotlight. Uses a headless `SCNRenderer.snapshot(...)`.

Both extensions share the same loading pipeline: `GLTFAsset.load(...)` → `GLTFSCNSceneSource(asset:)` → `SCNScene` with a framing camera derived from the model's bounding box.

See `CLAUDE.md` for additional architectural notes intended for AI coding assistants.

## Distribution (maintainers)

Notarized DMGs are produced from the same Makefile:

```sh
make notarize-setup   # one-time: prints the credential storage command
make release          # archive → export → DMG → notarize → staple
```

`make release` produces `dist/GLTFQuickLook.dmg` ready to attach to a GitHub release. See [`Makefile`](Makefile) for the full pipeline and overridable variables (`NOTARY_PROFILE`, `CONFIG`, etc.).

## Credits

This project is a rewrite of [magicien/GLTFQuickLook](https://github.com/magicien/GLTFQuickLook) by [@magicien](https://github.com/magicien), originally released in 2017 under the MIT license. The screenshots above are from the original project. Significant portions of the design and the `.gltf`/`.glb` UTI declarations are inherited from that work — without it this fork would not exist.

3D rendering is provided by [GLTFKit2](https://github.com/warrenm/GLTFKit2) by [Warren Moore](https://github.com/warrenm).

## License

[MIT](LICENSE) — original copyright © 2017 magicien, retained per the license terms.
