# GLTFQuickLook — local development + distribution.
#
# Local dev:
#   make                # build + install (Debug)
#   make CONFIG=Release install
#   make rebuild        # clean + install
#   make reload         # re-register installed bundle (no rebuild)
#   make uninstall
#
# Distribution (Developer ID + notarization):
#   make notarize-setup # one-time: prints how to store credentials
#   make release        # archive → export → DMG → notarize → staple
#
# See `make help` for all targets.

PROJECT      := GLTFQuickLook.xcodeproj
SCHEME       := GLTFQuickLook
CONFIG       ?= Debug
BUILD_DIR    := build
APP          := $(BUILD_DIR)/Build/Products/$(CONFIG)/GLTFQuickLook.app
INSTALL_DIR  := $(HOME)/Applications
INSTALLED    := $(INSTALL_DIR)/GLTFQuickLook.app
LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

# Distribution
TEAM_ID         := 6ZKL3ZKFLP
DIST_DIR        := dist
ARCHIVE         := $(DIST_DIR)/GLTFQuickLook.xcarchive
EXPORT_DIR      := $(DIST_DIR)/Export
EXPORT_APP      := $(EXPORT_DIR)/GLTFQuickLook.app
EXPORT_OPTIONS  := ExportOptions.plist
DMG             := $(DIST_DIR)/GLTFQuickLook.dmg
DMG_VOLNAME     := GLTFQuickLook
NOTARY_PROFILE  ?= GLTFQuickLook-Notary

.PHONY: all build clean install reinstall rebuild reload uninstall \
        archive export dmg notarize staple release dist-clean \
        notarize-setup help

all: install

# --- Local development ------------------------------------------------------

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	  -destination 'platform=macOS' -derivedDataPath $(BUILD_DIR) build

clean:
	-xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	  -derivedDataPath $(BUILD_DIR) clean
	rm -rf $(BUILD_DIR)

install: build
	@mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	$(LSREGISTER) -R -f -trusted $(INSTALLED)
	qlmanage -r
	qlmanage -r cache
	@echo ""
	@echo "Installed: $(INSTALLED)"
	@echo "Try Quick Look (Space) on a .glb or .gltf file in Finder."

reinstall:
	rm -rf $(INSTALLED)
	$(MAKE) install

rebuild: clean install

reload:
	$(LSREGISTER) -R -f -trusted $(INSTALLED)
	qlmanage -r
	qlmanage -r cache

uninstall:
	-$(LSREGISTER) -u $(INSTALLED)
	rm -rf $(INSTALLED)
	qlmanage -r
	qlmanage -r cache
	@echo "Uninstalled. Run 'killall Finder' to refresh icon caches if needed."

# --- Distribution -----------------------------------------------------------

archive:
	@mkdir -p $(DIST_DIR)
	rm -rf $(ARCHIVE)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  -destination 'generic/platform=macOS' \
	  -archivePath $(ARCHIVE) archive

export: $(EXPORT_APP)

$(EXPORT_APP): $(EXPORT_OPTIONS)
	$(MAKE) archive
	rm -rf $(EXPORT_DIR)
	xcodebuild -exportArchive -archivePath $(ARCHIVE) \
	  -exportPath $(EXPORT_DIR) \
	  -exportOptionsPlist $(EXPORT_OPTIONS)

dmg: $(DMG)

$(DMG): $(EXPORT_APP)
	rm -f $(DMG)
	rm -rf $(DIST_DIR)/dmg-staging
	mkdir -p $(DIST_DIR)/dmg-staging
	cp -R $(EXPORT_APP) $(DIST_DIR)/dmg-staging/
	ln -s /Applications $(DIST_DIR)/dmg-staging/Applications
	hdiutil create -volname $(DMG_VOLNAME) \
	  -srcfolder $(DIST_DIR)/dmg-staging \
	  -ov -format UDZO $(DMG)
	rm -rf $(DIST_DIR)/dmg-staging

notarize: $(DMG)
	@echo "Submitting $(DMG) to Apple notary service…"
	xcrun notarytool submit $(DMG) \
	  --keychain-profile $(NOTARY_PROFILE) \
	  --wait

staple: $(DMG)
	xcrun stapler staple $(DMG)
	xcrun stapler validate $(DMG)

release: dist-clean dmg notarize staple
	@echo ""
	@echo "Release artifact ready: $(DMG)"
	@echo "Upload it to your GitHub release."

dist-clean:
	rm -rf $(DIST_DIR)

# --- One-time setup ---------------------------------------------------------

notarize-setup:
	@echo "Run ONCE to store notarization credentials in your login keychain."
	@echo ""
	@echo "Option A — App Store Connect API key (recommended for CI):"
	@echo "  xcrun notarytool store-credentials $(NOTARY_PROFILE) \\"
	@echo "    --key /path/to/AuthKey_XXXXXXXX.p8 \\"
	@echo "    --key-id XXXXXXXX \\"
	@echo "    --issuer YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY"
	@echo ""
	@echo "Option B — Apple ID + app-specific password:"
	@echo "  xcrun notarytool store-credentials $(NOTARY_PROFILE) \\"
	@echo "    --apple-id YOUR_APPLE_ID \\"
	@echo "    --team-id $(TEAM_ID) \\"
	@echo "    --password YOUR_APP_SPECIFIC_PASSWORD"
	@echo ""
	@echo "Generate an app-specific password at https://appid.apple.com → Sign-In and Security."

# --- Help -------------------------------------------------------------------

help:
	@echo "Local development:"
	@echo "  build           xcodebuild into ./$(BUILD_DIR)"
	@echo "  install         build + copy to $(INSTALL_DIR) + lsregister + qlmanage -r"
	@echo "  reinstall       delete installed copy first, then install"
	@echo "  rebuild         clean + install"
	@echo "  reload          re-register installed bundle, no rebuild"
	@echo "  uninstall       unregister and delete from $(INSTALL_DIR)"
	@echo "  clean           xcodebuild clean + rm -rf $(BUILD_DIR)"
	@echo ""
	@echo "Distribution (Developer ID + notarization):"
	@echo "  archive         xcodebuild archive (Release) → $(ARCHIVE)"
	@echo "  export          export signed .app from archive → $(EXPORT_DIR)"
	@echo "  dmg             build a distributable .dmg → $(DMG)"
	@echo "  notarize        submit DMG to Apple notary service (needs credentials)"
	@echo "  staple          attach notarization ticket to DMG"
	@echo "  release         dist-clean + dmg + notarize + staple (full pipeline)"
	@echo "  dist-clean      rm -rf $(DIST_DIR)"
	@echo "  notarize-setup  prints one-time keychain credential setup instructions"
	@echo ""
	@echo "Variables:"
	@echo "  CONFIG=Debug|Release       (default: Debug, dev only — release uses Release)"
	@echo "  NOTARY_PROFILE=<name>      keychain profile for notarytool (default: $(NOTARY_PROFILE))"
