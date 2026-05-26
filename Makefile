PROJECT := calendar.xcodeproj
NIGHTLY_SCHEME := calendar Nightly
NIGHTLY_CONFIGURATION := Nightly
NIGHTLY_DERIVED_DATA := .build/xcode
NIGHTLY_PRODUCT := $(NIGHTLY_DERIVED_DATA)/Build/Products/Nightly/Callisto.app
NIGHTLY_INSTALL_DIR := $(HOME)/Applications
NIGHTLY_INSTALLED_APP := $(NIGHTLY_INSTALL_DIR)/Callisto Nightly.app

.PHONY: build install run clean

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

clean:
	rm -rf "$(NIGHTLY_DERIVED_DATA)"
	rm -rf "$(NIGHTLY_INSTALLED_APP)"
