SHELL := /bin/zsh

PROJECT_ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang)
MIN_IOS ?= 15.0
EXTRA_CFLAGS ?=
DYLIB := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions.dylib
DEB_STAGE := $(PROJECT_ROOT)/package/stage
DEB := $(PROJECT_ROOT)/packages/IsaacExternalItemDescriptions-rootless.deb
LIVECONTAINER_FRAMEWORK := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions.framework
LIVECONTAINER_ZIP := $(PROJECT_ROOT)/packages/IsaacExternalItemDescriptions-LiveContainer.framework.zip
EMBEDDED_STAGE := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions-Embedded
EMBEDDED_ZIP := $(PROJECT_ROOT)/dist/IsaacExternalItemDescriptions-Embedded.zip
DIST := $(PROJECT_ROOT)/dist
INCLUDE_DESCRIPTION_DB ?= 1
BUNDLED_DESCRIPTION_DB := $(PROJECT_ROOT)/data/descriptions.json
PARITY_BUNDLE := $(PROJECT_ROOT)/build/IsaacEID.bundle
STAGED_DESCRIPTION_DB := $(PARITY_BUNDLE)/descriptions.json

SOURCES := \
	$(PROJECT_ROOT)/src/EIDBootstrap.m \
	$(PROJECT_ROOT)/src/EIDLogger.m \
	$(PROJECT_ROOT)/src/EIDDescriptionStore.m \
	$(PROJECT_ROOT)/src/EIDNativeProbe.mm \
	$(PROJECT_ROOT)/src/EIDOverlayController.m \
	$(PROJECT_ROOT)/src/EIDParityPresentation.m \
	$(PROJECT_ROOT)/src/EIDHeaderTuning.m

.PHONY: all dylib descriptions parity-assets stage-release-bundle package livecontainer audit test release clean

all: dylib package

descriptions:
	@test -n "$(EID_SOURCE)" || (echo "Set EID_SOURCE=/path/to/External-Item-Descriptions"; exit 2)
	mkdir -p "$(PARITY_BUNDLE)"
	python3 "$(PROJECT_ROOT)/tools/import-eid.py" "$(EID_SOURCE)" "$(STAGED_DESCRIPTION_DB)"

parity-assets:
	@test -n "$(EID_SOURCE)" || (echo "Set EID_SOURCE=/path/to/External-Item-Descriptions"; exit 2)
	mkdir -p "$(PARITY_BUNDLE)"
	python3 "$(PROJECT_ROOT)/tools/import-eid-assets.py" "$(EID_SOURCE)" "$(PARITY_BUNDLE)"

stage-release-bundle:
	mkdir -p "$(PARITY_BUNDLE)"
	@test -f "$(BUNDLED_DESCRIPTION_DB)" || (echo "Bundled descriptions database is missing: $(BUNDLED_DESCRIPTION_DB)"; exit 2)
	cp "$(BUNDLED_DESCRIPTION_DB)" "$(STAGED_DESCRIPTION_DB)"
	@if test -n "$(EID_SOURCE)"; then \
		$(MAKE) parity-assets EID_SOURCE="$(EID_SOURCE)"; \
	fi
	@test -f "$(STAGED_DESCRIPTION_DB)"

dylib:
	mkdir -p "$(PROJECT_ROOT)/build"
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fmodules -O2 $(EXTRA_CFLAGS) -dynamiclib -I"$(PROJECT_ROOT)/include" \
		-Wl,-install_name,@rpath/IsaacExternalItemDescriptions.dylib -Wl,-dead_strip -Wl,-fatal_warnings \
		-Wl,-exported_symbols_list,"$(PROJECT_ROOT)/package/exports.txt" \
		$(SOURCES) -framework Foundation -framework UIKit -framework QuartzCore -lc++ -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	@if command -v codesign >/dev/null 2>&1; then codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaaceid.dylib "$(DYLIB)"; elif command -v ldid >/dev/null 2>&1; then ldid -S "$(DYLIB)"; fi

package: dylib
	rm -rf "$(DEB_STAGE)"
	mkdir -p "$(DEB_STAGE)/DEBIAN" "$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries"
	cp "$(PROJECT_ROOT)/package/control" "$(DEB_STAGE)/DEBIAN/control"
	cp "$(PROJECT_ROOT)/package/IsaacExternalItemDescriptions.plist" "$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacExternalItemDescriptions.plist"
	cp "$(DYLIB)" "$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacExternalItemDescriptions.dylib"
	@if test "$(INCLUDE_DESCRIPTION_DB)" = "1"; then \
		test -f "$(STAGED_DESCRIPTION_DB)" || (echo "Staged EID bundle is missing descriptions.json"; exit 2); \
		mkdir -p "$(DEB_STAGE)/var/jb/Library/Application Support/IsaacExternalItemDescriptions"; \
		cp -R "$(PARITY_BUNDLE)/." "$(DEB_STAGE)/var/jb/Library/Application Support/IsaacExternalItemDescriptions/"; \
	fi
	mkdir -p "$(PROJECT_ROOT)/packages"
	dpkg-deb --root-owner-group --build "$(DEB_STAGE)" "$(DEB)"

livecontainer: dylib
	rm -rf "$(LIVECONTAINER_FRAMEWORK)"
	mkdir -p "$(LIVECONTAINER_FRAMEWORK)/Resources"
	cp "$(DYLIB)" "$(LIVECONTAINER_FRAMEWORK)/IsaacExternalItemDescriptions"
	cp "$(PROJECT_ROOT)/livecontainer/Info.plist" "$(LIVECONTAINER_FRAMEWORK)/Info.plist"
	chmod 755 "$(LIVECONTAINER_FRAMEWORK)/IsaacExternalItemDescriptions"
	@if test "$(INCLUDE_DESCRIPTION_DB)" = "1"; then \
		test -f "$(STAGED_DESCRIPTION_DB)" || (echo "Staged EID bundle is missing descriptions.json"; exit 2); \
		mkdir -p "$(LIVECONTAINER_FRAMEWORK)/Resources/IsaacEID.bundle"; \
		cp -R "$(PARITY_BUNDLE)/." "$(LIVECONTAINER_FRAMEWORK)/Resources/IsaacEID.bundle/"; \
	fi
	mkdir -p "$(PROJECT_ROOT)/packages"; rm -f "$(LIVECONTAINER_ZIP)"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(LIVECONTAINER_FRAMEWORK)" "$(LIVECONTAINER_ZIP)"
	python3 "$(PROJECT_ROOT)/tests/test_livecontainer_package.py" "$(LIVECONTAINER_FRAMEWORK)" "$(LIVECONTAINER_ZIP)"

audit: dylib
	file "$(DYLIB)"; otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker|/var/jb'; then echo "ERROR: jailbreak-only dependency detected"; exit 1; else echo "Portable dependency audit passed"; fi

test:
	python3 "$(PROJECT_ROOT)/tests/test_import_eid.py"
	python3 "$(PROJECT_ROOT)/tests/test_bundled_descriptions.py"
	python3 -m py_compile "$(PROJECT_ROOT)/tools/import-eid.py" "$(PROJECT_ROOT)/tools/import-eid-assets.py" "$(PROJECT_ROOT)/tools/macho-add-dylib.py"
	zsh -n "$(PROJECT_ROOT)/tools/patch-ipa.sh"

release:
	rm -rf "$(DIST)"
	$(MAKE) test
	$(MAKE) stage-release-bundle EID_SOURCE="$(EID_SOURCE)"
	$(MAKE) package INCLUDE_DESCRIPTION_DB=1 EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) livecontainer INCLUDE_DESCRIPTION_DB=1 EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) audit EXTRA_CFLAGS='-Wall -Wextra -Werror'
	mkdir -p "$(DIST)"
	cp "$(DYLIB)" "$(DIST)/IsaacExternalItemDescriptions.dylib"
	cp "$(DEB)" "$(DIST)/IsaacExternalItemDescriptions-rootless.deb"
	cp "$(LIVECONTAINER_ZIP)" "$(DIST)/IsaacExternalItemDescriptions-LiveContainer.framework.zip"
	cp "$(STAGED_DESCRIPTION_DB)" "$(DIST)/descriptions.json"
	rm -rf "$(EMBEDDED_STAGE)"
	mkdir -p "$(EMBEDDED_STAGE)/IsaacEID.bundle"
	cp "$(DYLIB)" "$(EMBEDDED_STAGE)/IsaacExternalItemDescriptions.dylib"
	cp -R "$(PARITY_BUNDLE)/." "$(EMBEDDED_STAGE)/IsaacEID.bundle/"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(EMBEDDED_STAGE)" "$(EMBEDDED_ZIP)"
	cd "$(DIST)" && shasum -a 256 \
		IsaacExternalItemDescriptions.dylib \
		IsaacExternalItemDescriptions-rootless.deb \
		IsaacExternalItemDescriptions-LiveContainer.framework.zip \
		IsaacExternalItemDescriptions-Embedded.zip \
		descriptions.json > SHA256SUMS

clean:
	rm -rf "$(PROJECT_ROOT)/build" "$(PROJECT_ROOT)/package/stage" "$(DIST)"
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -name '*.deb' -delete
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -name '*.framework.zip' -delete
