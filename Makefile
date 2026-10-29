APP := build/SourisFacile.app
ICON := build/AppIcon.icns
ARCHS := --arch arm64 --arch x86_64
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
ZIP = build/SourisFacile-$(VERSION).zip
# "-" signs ad hoc. Use a stable identity (e.g. "Developer ID Application: …"
# or a self-signed certificate) so the Accessibility permission survives rebuilds.
SIGN_IDENTITY ?= -
# A keychain profile saved with `xcrun notarytool store-credentials`.
NOTARY_PROFILE ?= souris-facile
# Notarization needs a secure timestamp, which ad hoc signatures can't have.
TIMESTAMP := $(if $(filter -,$(SIGN_IDENTITY)),,--timestamp)

.PHONY: app run test install release notarize clean

# Universal (Apple Silicon + Intel) release build, packaged as an app bundle.
app: $(ICON)
	swift build -c release $(ARCHS)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/SourisFacile" $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	cp $(ICON) $(APP)/Contents/Resources/
	codesign --force --options runtime $(TIMESTAMP) --sign "$(SIGN_IDENTITY)" $(APP)
	lipo -archs $(APP)/Contents/MacOS/SourisFacile

$(ICON): Resources/AppIcon.png
	rm -rf build/AppIcon.iconset
	mkdir -p build/AppIcon.iconset
	for size in 16 32 128 256 512; do \
		sips -z $$size $$size $< --out build/AppIcon.iconset/icon_$${size}x$${size}.png >/dev/null; \
		sips -z $$((size * 2)) $$((size * 2)) $< --out build/AppIcon.iconset/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o $@

run: app
	open $(APP)

test:
	swift test

install: app
	rm -rf /Applications/SourisFacile.app
	cp -R $(APP) /Applications/

# A zip of the app, ready to share.
release: app
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	@echo $(ZIP)

# Notarizes the app with Apple and staples the ticket, so it opens without
# warnings on other Macs. Needs a Developer ID identity.
notarize: release
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo 'Set SIGN_IDENTITY="Developer ID Application: …" to notarize.'; exit 1; \
	fi
	xcrun notarytool submit $(ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(APP)
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	@echo $(ZIP)

clean:
	rm -rf .build build
