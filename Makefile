PREFIX   ?= $(HOME)/.local
BIN      := $(PREFIX)/bin/mic-guard
LABEL    := local.mic-guard
PLIST    := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG      := $(HOME)/Library/Logs/mic-guard.log
# Name patterns of the headsets whose microphone mic-guard replaces, as one
# plist <string> per pattern.
DEVICES  ?= Bose
DOMAIN   := gui/$(shell id -u)

.PHONY: build install uninstall restart status log clean

build: build/mic-guard

build/mic-guard: mic-guard.swift
	@mkdir -p build
	swiftc -O -o $@ $<

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
	rm -rf build
