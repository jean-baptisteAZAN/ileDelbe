# Changelog

All notable changes to ileDelbe are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-11-10

Styles and a settings window.

### Changed

- **Île is the new default style**: one compact module at a time, with pagination dots. The 0.2 look is still there as the **Onglets** style. Existing users get Île after updating; switch back in the settings.

### Added

- Three panel styles: Île, Grille (all modules at once) and Onglets. Île has a **Tout voir** button that shows the Grille layout.
- Réglages window (gear in the open panel, or right-click inside the open panel > **Réglages…**): style, accent (artwork, fixed tint or none) and halo intensity, module visibility and order, module opened first, closed-notch display (Pochette + égaliseur, Titre, Rien), **Animer l'encoche fermée**, hover-open delay, timer presets, panel size (Normale or Compacte), 3 or 5 recent files, and launch at login.
- Closed-notch animations honor Reduce Motion.
- README images for the three styles and the settings window.

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

[Unreleased]: https://github.com/jean-baptisteAZAN/ileDelbe/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/jean-baptisteAZAN/ileDelbe/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jean-baptisteAZAN/ileDelbe/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jean-baptisteAZAN/ileDelbe/releases/tag/v0.1.0
