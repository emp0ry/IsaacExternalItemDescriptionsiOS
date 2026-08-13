SHELL := /bin/zsh

PROJECT_ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang)
MIN_IOS ?= 15.0
EXTRA_CFLAGS ?=
DYLIB := $(PROJECT_ROOT)/build/IsaacExternalItemDescriptions.dylib
DEB_STAGE := $(PROJECT_ROOT)/package/stage
DEB := $(PROJECT_ROOT)/packages/IsaacExternalItemDescriptions-rootless.deb

SOURCES := \
	$(PROJECT_ROOT)/src/EIDBootstrap.m \
	$(PROJECT_ROOT)/src/EIDLogger.m \
	$(PROJECT_ROOT)/src/EIDDescriptionStore.m \
	$(PROJECT_ROOT)/src/EIDNativeProbe.mm \
	$(PROJECT_ROOT)/src/EIDOverlayController.m

.PHONY: all dylib descriptions package audit test clean

all: dylib package

descriptions:
	@test -n "$(EID_SOURCE)" || (echo "Set EID_SOURCE=/path/to/External-Item-Descriptions"; exit 2)
	mkdir -p "$(PROJECT_ROOT)/build/IsaacEID.bundle"
	python3 "$(PROJECT_ROOT)/tools/import-eid.py" "$(EID_SOURCE)" \
		"$(PROJECT_ROOT)/build/IsaacEID.bundle/descriptions.json"

dylib:
	mkdir -p "$(PROJECT_ROOT)/build"
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fmodules -O2 $(EXTRA_CFLAGS) -dynamiclib \
		-I"$(PROJECT_ROOT)/include" \
		-Wl,-install_name,@rpath/IsaacExternalItemDescriptions.dylib \
		-Wl,-dead_strip -Wl,-fatal_warnings \
		-Wl,-exported_symbols_list,"$(PROJECT_ROOT)/package/exports.txt" \
		$(SOURCES) -framework Foundation -framework UIKit -framework QuartzCore -lc++ -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	@if command -v codesign >/dev/null 2>&1; then \
		codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaaceid.dylib "$(DYLIB)"; \
	elif command -v ldid >/dev/null 2>&1; then ldid -S "$(DYLIB)"; fi

package: dylib
	rm -rf "$(DEB_STAGE)"
	mkdir -p "$(DEB_STAGE)/DEBIAN" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries"
	cp "$(PROJECT_ROOT)/package/control" "$(DEB_STAGE)/DEBIAN/control"
	cp "$(PROJECT_ROOT)/package/IsaacExternalItemDescriptions.plist" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacExternalItemDescriptions.plist"
	cp "$(DYLIB)" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacExternalItemDescriptions.dylib"
	@if test -f "$(PROJECT_ROOT)/build/IsaacEID.bundle/descriptions.json"; then \
		mkdir -p "$(DEB_STAGE)/var/jb/Library/Application Support/IsaacExternalItemDescriptions"; \
		cp "$(PROJECT_ROOT)/build/IsaacEID.bundle/descriptions.json" \
			"$(DEB_STAGE)/var/jb/Library/Application Support/IsaacExternalItemDescriptions/descriptions.json"; \
	fi
	mkdir -p "$(PROJECT_ROOT)/packages"
	dpkg-deb --root-owner-group --build "$(DEB_STAGE)" "$(DEB)"

audit: dylib
	file "$(DYLIB)"
	otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker|/var/jb'; then \
		echo "ERROR: jailbreak-only dependency detected"; exit 1; \
	else echo "Portable dependency audit passed"; fi

test:
	python3 "$(PROJECT_ROOT)/tests/test_import_eid.py"
	python3 -m py_compile "$(PROJECT_ROOT)/tools/import-eid.py" \
		"$(PROJECT_ROOT)/tools/macho-add-dylib.py"
	zsh -n "$(PROJECT_ROOT)/tools/patch-ipa.sh"

clean:
	rm -rf "$(PROJECT_ROOT)/build" "$(PROJECT_ROOT)/package/stage"
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -name '*.deb' -delete
