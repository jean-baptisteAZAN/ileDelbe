# Changelog

All notable changes to ileDelbe are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-09

The notch becomes a hub ("Stack").

### Added

- Artwork-colored halo: the average artwork color tints a glow around the closed notch, under the open panel, behind the big artwork and on the seek bar.
- Tabbed panel: Musique, Minuteur, Agenda and Fichiers, with an automatic default tab and an info line for an event starting within 60 minutes.
- Listening history: the last 3 tracks in the Musique tab.
- Timer: one timer at a time (5, 10 or 25 min) with +1 min, pause, resume and stop. The "Glass" sound and an orange notch when it ends. It survives a relaunch.
- Timer bubble next to the notch when a timer runs while music plays.
- Agenda: the next 2 events of the next 24 hours from all calendars, with a join button for Google Meet, Zoom and Microsoft Teams links.
- Recent files: the 3 most recently used files, open on click or drag out of the panel.
- Release tooling: `make release` (Developer ID signing, notarization, zip and SHA-256), a Homebrew cask, and `make readme-assets` for generated README images.

### Fixed

- The hub works without the Now Playing adapter (music disabled, other tabs available).
- The open panel lets clicks through its transparent glow margin.

## [0.1.0] - 2026-11-09

First version: a Now Playing media panel in the notch.

### Added

- Closed notch "wings" while something plays: artwork and an animated equalizer.
- Hover panel with artwork, title, artist, play/pause, previous, next, a seek bar and the system volume.
- Now Playing for any source macOS reports (Spotify, Music, browsers), through the vendored mediaremote-adapter.
- Non-activating panel that never takes focus and passes clicks outside its shape to the menu bar.

[Unreleased]: https://github.com/jean-baptisteAZAN/ileDelbe/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jean-baptisteAZAN/ileDelbe/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jean-baptisteAZAN/ileDelbe/releases/tag/v0.1.0
