# mic-guard

Keeps chosen Bluetooth headsets off the macOS microphone, so they never drop
into the hissy hands-free mode.

A Bluetooth headset can't play stereo audio and use its microphone at the same
time: as soon as an app records from it, it switches from A2DP (stereo,
44.1 kHz) to the hands-free profile (mono, 16 kHz), and you hear noise until
recording stops. mic-guard listens for macOS's "default input device changed"
event (CoreAudio, no polling). When the new input's name matches one of the
given patterns, it switches the input to the MacBook's built-in microphone.
Every other device, AirPods included, keeps its own microphone.

## Use

```sh
make install                 # build, copy to ~/.local/bin, load the LaunchAgent
make install DEVICES="Bose Sony"   # several headsets (name substrings, any case)
make status                  # is it running
make log                     # what it switched, from ~/Library/Logs/mic-guard.log
make uninstall               # stop it and remove the binary and LaunchAgent
```

`mic-guard --list` prints the input devices, `*` marking the current one.
Needs only the Swift compiler from the Xcode Command Line Tools, and no
privacy permissions: it changes which device is the default, it never opens
a microphone.

## Limits

- Apps that pick a microphone by name (Zoom, Teams, Meet) must be set to
  "Same as System" or the MacBook microphone. An app set to the headset by
  name still opens it, and the noise comes back.
- When the headset connects, macOS selects its microphone first and mic-guard
  switches it back a moment later. A call already recording at that instant
  may keep the headset microphone.
- If you pick the headset microphone yourself in System Settings, mic-guard
  switches it back too. Stop it (`make uninstall`, or
  `launchctl bootout gui/$(id -u)/local.mic-guard`) for that.
