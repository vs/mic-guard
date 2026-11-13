PREFIX   ?= $(HOME)/.local
BIN      := $(PREFIX)/bin/mic-guard
LABEL    := local.mic-guard
PLIST    := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG      := $(HOME)/Library/Logs/mic-guard.log
# Name patterns of the headsets whose microphone mic-guard replaces, as one
# plist <string> per pattern.
DEVICES  ?= Bose
DOMAIN   := gui/$(shell id -u)
VERSION  := $(shell sed -n 's/^let version = "\(.*\)"$$/\1/p' mic-guard.swift)
MIN_OS   := 12.0
ARCHIVE  := mic-guard-$(VERSION)-macos-universal.tar.gz

.PHONY: build install uninstall restart status log clean release

build: build/mic-guard

build/mic-guard: mic-guard.swift
	@mkdir -p build
	swiftc -O -o $@ $<

# One binary for Apple silicon and Intel, ad-hoc signed, packed with the docs.
release: dist/$(ARCHIVE)

dist/$(ARCHIVE): mic-guard.swift README.md LICENSE CHANGELOG.md
	@rm -rf build/release dist && mkdir -p build/release/pkg dist
	swiftc -O -target arm64-apple-macos$(MIN_OS) -o build/release/mic-guard-arm64 mic-guard.swift
	swiftc -O -target x86_64-apple-macos$(MIN_OS) -o build/release/mic-guard-x86_64 mic-guard.swift
	lipo -create -output build/release/pkg/mic-guard build/release/mic-guard-arm64 build/release/mic-guard-x86_64
	codesign --force --sign - build/release/pkg/mic-guard
	cp README.md LICENSE CHANGELOG.md build/release/pkg/
	COPYFILE_DISABLE=1 tar -czf $@ -C build/release/pkg mic-guard README.md LICENSE CHANGELOG.md
	cd dist && shasum -a 256 $(ARCHIVE) > $(ARCHIVE).sha256
	@echo "built dist/$(ARCHIVE)"

install: build
	@mkdir -p $(dir $(BIN)) $(dir $(PLIST))
	install -m 755 build/mic-guard $(BIN)
	sed -e 's|@LABEL@|$(LABEL)|' -e 's|@BIN@|$(BIN)|' -e 's|@LOG@|$(LOG)|' \
	    -e 's|@DEVICES@|$(foreach d,$(DEVICES),<string>$(d)</string>)|' \
	    mic-guard.plist.in > $(PLIST)
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	launchctl bootstrap $(DOMAIN) $(PLIST)
	@echo "mic-guard is running; log: $(LOG)"

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -f $(PLIST) $(BIN)

restart:
	launchctl kickstart -k $(DOMAIN)/$(LABEL)

status:
	@launchctl print $(DOMAIN)/$(LABEL) 2>/dev/null | grep -E '^\s+(state|pid|last exit code) =' || echo "not loaded"

log:
	@tail -n 20 $(LOG)

clean:
	rm -rf build dist
