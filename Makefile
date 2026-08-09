PROJECT := calendar.xcodeproj
NIGHTLY_SCHEME := nightly
NIGHTLY_CONFIGURATION := Nightly
NIGHTLY_DERIVED_DATA := .build/xcode
NIGHTLY_PRODUCT := $(NIGHTLY_DERIVED_DATA)/Build/Products/Nightly/Callisto.app
NIGHTLY_INSTALL_DIR := $(HOME)/Applications
NIGHTLY_INSTALLED_APP := $(NIGHTLY_INSTALL_DIR)/Callisto Nightly.app

.PHONY: build install run open clean

build:
	xcodebuild -project "$(PROJECT)" \
		-scheme "$(NIGHTLY_SCHEME)" \
		-configuration "$(NIGHTLY_CONFIGURATION)" \
		-destination "platform=macOS" \
		-derivedDataPath "$(NIGHTLY_DERIVED_DATA)" \
		build

install: build
	mkdir -p "$(NIGHTLY_INSTALL_DIR)"
	ditto "$(NIGHTLY_PRODUCT)" "$(NIGHTLY_INSTALLED_APP)"

run: install
	open "$(NIGHTLY_INSTALLED_APP)"

# Reveals the build output directory in Finder.
open:
	open "$(dir $(NIGHTLY_PRODUCT))"

clean:
	rm -rf "$(NIGHTLY_DERIVED_DATA)"
	rm -rf "$(NIGHTLY_INSTALLED_APP)"
