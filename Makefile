SHELL := /bin/zsh
.DEFAULT_GOAL := all

PROJECT_ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang)
HOST_SDK := $(shell xcrun --sdk macosx --show-sdk-path)
HOST_CLANGXX := $(shell xcrun --sdk macosx --find clang++)
MIN_IOS ?= 15.0
EXTRA_CFLAGS ?=
DYLIB := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions.dylib
PLAYCOVER_DYLIB := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions-PlayCover.dylib
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
	$(PROJECT_ROOT)/src/EIDGameHost.mm \
	$(PROJECT_ROOT)/src/EIDLogger.m \
	$(PROJECT_ROOT)/src/EIDDescriptionStore.m \
	$(PROJECT_ROOT)/src/EIDContextDescriptions.m \
	$(PROJECT_ROOT)/src/EIDDynamicDescriptions.m \
	$(PROJECT_ROOT)/src/EIDAdvancedDescriptions.m \
	$(PROJECT_ROOT)/src/EIDCharacterSynergies.m \
	$(PROJECT_ROOT)/src/EIDQualityFix.m \
	$(PROJECT_ROOT)/src/EIDNativeProbe.mm \
	$(PROJECT_ROOT)/src/EIDOverlayController.m \
	$(PROJECT_ROOT)/src/EIDPocketArtworkFix.m \
	$(PROJECT_ROOT)/src/EIDCardFrameFix.m \
	$(PROJECT_ROOT)/src/EIDPillFrameFix.m \
	$(PROJECT_ROOT)/src/EIDParityPresentation.m \
	$(PROJECT_ROOT)/src/EIDSettings.m \
	$(PROJECT_ROOT)/src/EIDUILocalization.m \
	$(PROJECT_ROOT)/src/EIDBitmapFont.mm \
	$(PROJECT_ROOT)/src/EIDOriginalScene.mm \
	$(PROJECT_ROOT)/src/EIDOriginalRenderer.mm \
	$(PROJECT_ROOT)/src/EIDTransformationProgress.m

.PHONY: all dylib playcover descriptions parity-assets stage-release-bundle package livecontainer audit check test local-test release clean

.PHONY: original-test original-check
original-test: original-check
	"$(HOST_CLANGXX)" -isysroot "$(HOST_SDK)" -std=c++17 -Wall -Wextra -Werror -I"$(PROJECT_ROOT)/include" \
		"$(PROJECT_ROOT)/tests/test_original_font.cpp" -o "$(PROJECT_ROOT)/build/test_original_font"
	"$(PROJECT_ROOT)/build/test_original_font" "$(PARITY_BUNDLE)/fonts/eid_default.fnt"

original-check: stage-release-bundle
	"$(HOST_CLANGXX)" -isysroot "$(HOST_SDK)" -std=c++17 -fobjc-arc -Wall -Wextra -Werror -I"$(PROJECT_ROOT)/include" \
		"$(PROJECT_ROOT)/src/EIDBitmapFont.mm" "$(PROJECT_ROOT)/src/EIDOriginalScene.mm" \
		"$(PROJECT_ROOT)/tools/preview-original-renderer.mm" \
		-framework Foundation -framework CoreGraphics -framework ImageIO -o "$(PROJECT_ROOT)/build/preview-original-renderer"
	"$(PROJECT_ROOT)/build/preview-original-renderer" "$(PARITY_BUNDLE)" "$(PROJECT_ROOT)/build/original-renderer-preview.png"
	python3 "$(PROJECT_ROOT)/tools/audit-original-presentation.py" --strict

all: dylib package

descriptions:
	@test -n "$(EID_SOURCE)" || (echo "Set EID_SOURCE=/path/to/External-Item-Descriptions"; exit 2)
	mkdir -p "$(PARITY_BUNDLE)"
	python3 "$(PROJECT_ROOT)/tools/import-eid.py" "$(EID_SOURCE)" "$(STAGED_DESCRIPTION_DB)"

parity-assets:
	@test -n "$(EID_SOURCE)" || (echo "Set EID_SOURCE=/path/to/External-Item-Descriptions"; exit 2)
	mkdir -p "$(PARITY_BUNDLE)"
	python3 "$(PROJECT_ROOT)/tools/import-eid-assets.py" "$(EID_SOURCE)" "$(PARITY_BUNDLE)"
	python3 "$(PROJECT_ROOT)/tools/import-original-renderer.py" "$(EID_SOURCE)" "$(PARITY_BUNDLE)"

stage-release-bundle:
	mkdir -p "$(PARITY_BUNDLE)"
	@test -f "$(BUNDLED_DESCRIPTION_DB)" || (echo "Bundled descriptions database is missing: $(BUNDLED_DESCRIPTION_DB)"; exit 2)
	cp "$(BUNDLED_DESCRIPTION_DB)" "$(STAGED_DESCRIPTION_DB)"
	@if test -n "$(EID_SOURCE)"; then \
		$(MAKE) parity-assets EID_SOURCE="$(EID_SOURCE)"; \
	fi
	cp "$(PROJECT_ROOT)/THIRD_PARTY_NOTICES.md" "$(PARITY_BUNDLE)/THIRD_PARTY_NOTICES.md"
	cp "$(PROJECT_ROOT)/LICENSE" "$(PARITY_BUNDLE)/IsaacEID-bridge-LICENSE.txt"
	@test -f "$(STAGED_DESCRIPTION_DB)"

dylib:
	mkdir -p "$(PROJECT_ROOT)/build"
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fmodules -fno-autolink -O2 $(EXTRA_CFLAGS) -dynamiclib -I"$(PROJECT_ROOT)/include" \
		-Wl,-install_name,@rpath/IsaacExternalItemDescriptions.dylib -Wl,-dead_strip -Wl,-fatal_warnings \
		-Wl,-exported_symbols_list,"$(PROJECT_ROOT)/package/exports.txt" \
		$(SOURCES) -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework ImageIO -lc++ -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	@if command -v codesign >/dev/null 2>&1; then codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaaceid.dylib "$(DYLIB)"; elif command -v ldid >/dev/null 2>&1; then ldid -S "$(DYLIB)"; fi

playcover: dylib
	xcrun vtool -set-build-version maccatalyst 15.0 15.0 -replace -output "$(PLAYCOVER_DYLIB)" "$(DYLIB)"
	codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaaceid.dylib "$(PLAYCOVER_DYLIB)"
	codesign --verify --strict "$(PLAYCOVER_DYLIB)"

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
	@if test -f "$(PROJECT_ROOT)/tests/test_livecontainer_package.py"; then \
		python3 "$(PROJECT_ROOT)/tests/test_livecontainer_package.py" "$(LIVECONTAINER_FRAMEWORK)" "$(LIVECONTAINER_ZIP)"; \
	fi

audit: dylib
	file "$(DYLIB)"; otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker|/var/jb'; then echo "ERROR: jailbreak-only dependency detected"; exit 1; else echo "Portable dependency audit passed"; fi

check:
	python3 "$(PROJECT_ROOT)/tools/release-notes.py" "$$(awk '/^Version:/ { print $$2 }' "$(PROJECT_ROOT)/package/control")" > /dev/null
	python3 -m py_compile "$(PROJECT_ROOT)/tools/import-eid.py" "$(PROJECT_ROOT)/tools/eid_context.py" "$(PROJECT_ROOT)/tools/eid_supplemental.py" "$(PROJECT_ROOT)/tools/eid_outcome_strings.py" "$(PROJECT_ROOT)/tools/import-eid-assets.py" "$(PROJECT_ROOT)/tools/macho-add-dylib.py" "$(PROJECT_ROOT)/tools/release-notes.py"
	zsh -n "$(PROJECT_ROOT)/tools/patch-ipa.sh"

test: check
	@if test -f "$(PROJECT_ROOT)/tests/test_pickup_policy.cpp"; then \
		$(MAKE) local-test; \
	else \
		echo "Local-only test suite is not installed; source and release checks passed."; \
	fi

local-test:
	mkdir -p "$(PROJECT_ROOT)/build"
	"$(HOST_CLANGXX)" -isysroot "$(HOST_SDK)" -std=c++17 -Wall -Wextra -Werror -I"$(PROJECT_ROOT)/include" \
		"$(PROJECT_ROOT)/tests/test_pickup_policy.cpp" -o "$(PROJECT_ROOT)/build/test_pickup_policy"
	"$(PROJECT_ROOT)/build/test_pickup_policy"
	"$(HOST_CLANGXX)" -isysroot "$(HOST_SDK)" -fobjc-arc -Wall -Wextra -Werror -I"$(PROJECT_ROOT)/include" \
		"$(PROJECT_ROOT)/tests/test_context_descriptions.m" "$(PROJECT_ROOT)/src/EIDContextDescriptions.m" \
		"$(PROJECT_ROOT)/tests/test_advanced_descriptions.m" \
		"$(PROJECT_ROOT)/src/EIDDynamicDescriptions.m" \
		"$(PROJECT_ROOT)/src/EIDAdvancedDescriptions.m" \
		"$(PROJECT_ROOT)/src/EIDCharacterSynergies.m" \
		"$(PROJECT_ROOT)/src/EIDTransformationProgress.m" "$(PROJECT_ROOT)/src/EIDLogger.m" \
		-framework Foundation -o "$(PROJECT_ROOT)/build/test_context_descriptions"
	"$(PROJECT_ROOT)/build/test_context_descriptions" "$(BUNDLED_DESCRIPTION_DB)"
	"$(HOST_CLANGXX)" -isysroot "$(HOST_SDK)" -fobjc-arc -Wall -Wextra -Werror -I"$(PROJECT_ROOT)/include" \
		"$(PROJECT_ROOT)/tests/test_ui_localization.m" "$(PROJECT_ROOT)/src/EIDUILocalization.m" \
		-framework Foundation -o "$(PROJECT_ROOT)/build/test_ui_localization"
	"$(PROJECT_ROOT)/build/test_ui_localization" "$(BUNDLED_DESCRIPTION_DB)"
	python3 "$(PROJECT_ROOT)/tests/test_overlay_architecture.py"
	python3 "$(PROJECT_ROOT)/tests/test_import_eid.py"
	python3 "$(PROJECT_ROOT)/tests/test_modular_import.py"
	python3 "$(PROJECT_ROOT)/tests/test_import_eid_assets.py"
	python3 "$(PROJECT_ROOT)/tests/test_bundled_descriptions.py"
	python3 "$(PROJECT_ROOT)/tests/test_documentation.py"

release:
	rm -rf "$(DIST)"
	$(MAKE) test
	$(MAKE) stage-release-bundle EID_SOURCE="$(EID_SOURCE)"
	$(MAKE) original-check
	$(MAKE) package INCLUDE_DESCRIPTION_DB=1 EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) livecontainer INCLUDE_DESCRIPTION_DB=1 EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) audit EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) playcover EXTRA_CFLAGS='-Wall -Wextra -Werror'
	mkdir -p "$(DIST)"
	cp "$(DYLIB)" "$(DIST)/IsaacExternalItemDescriptions.dylib"
	cp "$(PLAYCOVER_DYLIB)" "$(DIST)/IsaacExternalItemDescriptions-PlayCover.dylib"
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
		IsaacExternalItemDescriptions-PlayCover.dylib \
		IsaacExternalItemDescriptions-rootless.deb \
		IsaacExternalItemDescriptions-LiveContainer.framework.zip \
		IsaacExternalItemDescriptions-Embedded.zip \
		descriptions.json > SHA256SUMS

clean:
	rm -rf "$(PROJECT_ROOT)/build" "$(PROJECT_ROOT)/package/stage" "$(DIST)"
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -name '*.deb' -delete
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -name '*.framework.zip' -delete
