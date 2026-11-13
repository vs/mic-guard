# Changelog

All notable changes to mic-guard are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-13

### Added

- Watch CoreAudio's default input device and switch it to the built-in
  microphone whenever it becomes a device whose name contains one of the given
  patterns (case-insensitive).
- `--list` prints the input devices and marks the current default.
- `--version` and `--help`.
- `make install` / `make uninstall` build from source and manage a
  LaunchAgent that keeps mic-guard running at login.
- `make release` builds a universal (Apple silicon and Intel) binary for
  macOS 12 and later, packed with a SHA-256 checksum.

[Unreleased]: https://github.com/vs/mic-guard/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/vs/mic-guard/releases/tag/v0.1.0
