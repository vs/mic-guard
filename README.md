# mic-guard

Keeps chosen Bluetooth headsets off the macOS microphone, so they never drop
into the hissy hands-free mode.

## Why

A Bluetooth headset can't play stereo audio and use its microphone at the same
time. As soon as an app records from it, the headset switches from A2DP
(stereo, 44.1 kHz) to the hands-free profile (mono, 16 kHz): music turns flat
and you hear a hiss until recording stops. macOS makes this the default by
picking the headset's microphone every time it connects.

mic-guard listens for macOS's "default input device changed" event (CoreAudio,
no polling). When the new input's name matches one of the patterns you give,
it switches the input to the Mac's built-in microphone. The headset stays in
A2DP, and every other device, AirPods included, keeps its own microphone.

It needs no privacy permissions: it only changes which device is the default
and never opens a microphone. It's a single Swift file with no dependencies.

## Install

### With mise

```sh
mise use -g github:vs/mic-guard
```

### From a release

Download `mic-guard-<version>-macos-universal.tar.gz` from
[Releases](https://github.com/vs/mic-guard/releases). It runs on Apple
silicon and Intel Macs with macOS 12 or later.

```sh
curl -fsSLO https://github.com/vs/mic-guard/releases/download/v0.1.0/mic-guard-0.1.0-macos-universal.tar.gz
tar -xzf mic-guard-0.1.0-macos-universal.tar.gz mic-guard
mkdir -p ~/.local/bin && mv mic-guard ~/.local/bin/
```

The binary is ad-hoc signed, not notarized. `curl` doesn't mark downloads as
quarantined, but a browser does. If macOS refuses to open the file, run
`xattr -d com.apple.quarantine ~/.local/bin/mic-guard`.

### From source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/vs/mic-guard && cd mic-guard
make install
```

`make install` builds the binary, copies it to `~/.local/bin`, and loads a
LaunchAgent that starts it now and at every login.

## Usage

```sh
mic-guard Bose               # redirect any input whose name contains "Bose"
mic-guard Bose "WH-1000XM"   # several headsets
mic-guard --list             # input devices, * marks the current default
mic-guard --version
```

Patterns are case-insensitive substrings of the device name, as shown in
System Settings → Sound → Input or by `mic-guard --list`.

mic-guard logs each switch to stdout:

```
2026-11-13T12:19:10+01:00 watching for: Bose
2026-11-13T12:19:11+01:00 default input was Bose QC35 II, switched to MacBook Pro Microphone
```

## Run it at login

`make install` from a clone sets this up, with `DEVICES` for the patterns:

```sh
make install DEVICES="Bose Sony"
make status        # is it running
make log           # recent switches (~/Library/Logs/mic-guard.log)
make uninstall     # stop it and remove the binary and LaunchAgent
```

To run a release binary at login, save this as
`~/Library/LaunchAgents/local.mic-guard.plist`, replacing `USER` with your
username:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>local.mic-guard</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Users/USER/.local/bin/mic-guard</string>
		<string>Bose</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/Users/USER/Library/Logs/mic-guard.log</string>
	<key>StandardErrorPath</key>
	<string>/Users/USER/Library/Logs/mic-guard.log</string>
</dict>
</plist>
```

Then load it with
`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.mic-guard.plist`.

With mise's bootstrap, declare the agent instead:

```toml
[tools]
"github:vs/mic-guard" = "latest"

[bootstrap.macos.launchd.agents.mic-guard]
program = "~/.local/share/mise/shims/mic-guard"
args = ["Bose"]
run_at_load = true
keep_alive = true
stdout_path = "~/Library/Logs/mic-guard.log"
stderr_path = "~/Library/Logs/mic-guard.log"
```

## Limits

- Apps that pick a microphone by name (Zoom, Teams, Meet) must be set to
  "Same as System" or the built-in microphone. An app set to the headset by
  name still opens it, and the headset drops to hands-free mode.
- When the headset connects, macOS selects its microphone first and mic-guard
  switches it back a moment later. A call already recording at that instant
  may keep the headset microphone.
- If you pick the headset microphone yourself, mic-guard switches it back too.
  Stop mic-guard to use it.
- With the lid closed, the built-in microphone may be unavailable. mic-guard
  then logs that it found none and leaves the input alone.

## Releasing

1. Bump `version` in `mic-guard.swift` and add a section to `CHANGELOG.md`.
2. `make release` builds `dist/mic-guard-<version>-macos-universal.tar.gz`
   and its `.sha256`.
3. Commit, then tag and publish:

   ```sh
   git tag -a v<version> -m "mic-guard <version>" && git push --follow-tags
   gh release create v<version> dist/* --title "mic-guard <version>" --notes-file <notes>
   ```

## License

[MIT](LICENSE)
