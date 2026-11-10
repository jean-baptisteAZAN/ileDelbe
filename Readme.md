<div align="center">

# ileDelbe

**Your MacBook notch, turned into a little Dynamic Island.**

Now Playing controls, a timer, your next meetings and recent files, one hover away.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 15.4+](https://img.shields.io/badge/macOS-15.4%2B-black.svg?logo=apple)](#requirements)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138.svg?logo=swift&logoColor=white)](Package.swift)

<img src="docs/assets/hero.png" alt="The ileDelbe panel open under the notch, playing a track, with a pink halo" width="100%">

</div>

ileDelbe is a small, native macOS agent app (SwiftUI, no Dock icon, no menu bar item). It sits on the notch, grows when something happens, and opens into a panel when you hover it. It never steals focus, and clicks outside its shape go to the menu bar as usual.

> The app's interface is in French for now (*Musique*, *Minuteur*, *Agenda*, *Fichiers*). This README is in English.

## Features

- **Now Playing in the notch.** While something plays, the notch grows small wings: the artwork on the left, an animated equalizer on the right. It follows whatever macOS treats as "Now Playing": Spotify, Music, a YouTube tab, and so on.
- **Media panel.** Hover to open: artwork, title, artist, play/pause, previous, next, a seek bar, the system volume and your last 3 tracks.
- **Artwork-colored halo.** The average color of the current artwork tints a soft glow around the notch, the panel, and the seek bar. Grey or very dark artwork gives no glow.
- **Timer.** One timer at a time (5, 10 or 25 min), with +1 min, pause and stop. When it ends, macOS plays the "Glass" sound and the notch turns orange until you look at it. It survives a relaunch.
- **Timer bubble.** When a timer runs while music plays, the timer moves to a small bubble next to the notch, like two iPhone Live Activities.
- **Agenda.** Your next 2 events in the next 24 hours from all your macOS calendars, with a **Rejoindre** (join) button for Google Meet, Zoom and Microsoft Teams links. An imminent event shows as "<title> dans N min" in the panel.
- **Recent files.** Your 3 most recently used files, as in Finder's Recents. Click to open, or drag one out of the panel into another app.

## Screenshots

| Closed, music playing | Closed, music + timer bubble |
| :---: | :---: |
| <img src="docs/assets/closed-playing.png" alt="Closed notch with artwork and equalizer"> | <img src="docs/assets/closed-bubble.png" alt="Closed notch with a timer bubble on its right"> |
| **Musique** | **Minuteur** |
| <img src="docs/assets/open-music.png" alt="Music tab"> | <img src="docs/assets/open-timer.png" alt="Timer tab"> |
| **Agenda** | **Fichiers** |
| <img src="docs/assets/open-agenda.png" alt="Agenda tab with a join button"> | <img src="docs/assets/open-files.png" alt="Recent files tab"> |

<sub>These images are rendered from the app's real SwiftUI views with made-up sample data (`make readme-assets`).</sub>

## Install

### Homebrew (recommended)

```sh
brew tap jean-baptisteAZAN/tap
brew trust jean-baptisteAZAN/tap   # recent Homebrew asks you to trust third-party taps once
brew install --cask iledelbe
```

Update with `brew upgrade --cask iledelbe`. Uninstall with `brew uninstall --cask iledelbe` (add `--zap` to also remove its preferences).

### Manual download

1. Download `ileDelbe-<version>.zip` from the [latest release](https://github.com/jean-baptisteAZAN/ileDelbe/releases/latest).
2. Unzip it and move **IleDelbe.app** to `/Applications`.
3. Open it. Nothing appears in the Dock: look at your notch.

### Requirements

- A MacBook with a notch (Apple silicon), running **macOS 15.4 or later**.
- External screens and Macs without a notch are not supported.

## First launch and permissions

ileDelbe asks for permissions only when a feature needs them.

- **Calendar.** macOS asks for Calendar access the first time you open the **Agenda** tab, never before. If you refuse, the tab offers **Ouvrir les Réglages**, which opens System Settings > Privacy & Security > Calendars.
- **Files.** The **Fichiers** tab uses Spotlight. macOS may ask once for access to folders such as Desktop, Documents or Downloads when the app reads a recent file's icon or opens it.
- **Music.** Now Playing needs no permission.

To start ileDelbe at login, add it in System Settings > General > Login Items.

## Usage

- **Hover the notch** to open the panel. Move the pointer away to close it.
- **Tabs.** *Musique*, *Minuteur*, *Agenda* and *Fichiers*. The panel opens on *Minuteur* if a timer rang and you have not seen it yet, else on *Musique* if something plays, else on the last tab you used.
- **Timer bubble.** Hover the bubble to open the panel on *Minuteur*.
- **Quit.** Open the panel, right-click it and choose **Quitter**. From a terminal: `pkill -x IleDelbe`.

## Build from source

You need:

- Xcode 16 or later (the full Xcode, not only the Command Line Tools: the SwiftUI previews need its macro plugins).
- `cmake`, to build the Now Playing adapter: `brew install cmake`.

```sh
git clone --recurse-submodules https://github.com/jean-baptisteAZAN/ileDelbe.git
cd ileDelbe
# already cloned without submodules? run: git submodule update --init

make test           # run the test suite
make app            # build build/IleDelbe.app (signed ad hoc)
make run            # build and launch
make release        # build build/ileDelbe-<version>.zip (see scripts/release.sh)
make readme-assets  # regenerate the README images
```

`make release` signs with your Developer ID and notarizes when `DEVELOPER_ID_APP` and `NOTARY_PROFILE` are set. Without them, it signs ad hoc and warns you that the build will not pass Gatekeeper on other Macs.

## How it works

ileDelbe is a Swift package with two targets:

- **`IleDelbeCore`** holds the logic with no UI: notch geometry, the hover state machine, the timer, panel rules, halo color math, agenda filtering, meeting link detection, recent file selection, and the decoder for the Now Playing stream. The tests cover this target.
- **`IleDelbe`** is the app: a borderless, non-activating panel placed over the notch, SwiftUI views that take plain values (each has previews), and services that talk to macOS (EventKit for the agenda, Spotlight for recent files, CoreAudio for the volume).

Now Playing comes from [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), vendored as a git submodule. The app runs its script with the system `/usr/bin/perl`, which loads the adapter framework and streams JSON updates that `IleDelbeCore` decodes. Commands (play/pause, next, seek) go back through the same adapter.

## Known risk: MediaRemote

macOS 15.4 closed the private `MediaRemote` framework to third-party apps. The adapter is a workaround that runs through the system Perl, and Apple may break it in a future macOS release.

If the adapter is missing or fails, the music features are disabled (the panel shows "Rien en lecture") while the timer, agenda and files keep working. ileDelbe logs one error, which you can see with:

```sh
log stream --predicate 'subsystem == "io.github.ileDelbe"'
```

## FAQ and troubleshooting

**The Agenda tab stays empty after an update.**
macOS ties permissions to the app's signature. After an update, or after each `make app` for a local build, the old grant can go stale. Open System Settings > Privacy & Security > Calendars, remove ileDelbe, then open the Agenda tab again to get a new prompt.

**Nothing happens on my Mac.**
ileDelbe needs a built-in screen with a notch. Macs without a notch and external screens are not supported.

**Music controls show "Rien en lecture" while something plays.**
See [Known risk](#known-risk-mediaremote) and check the logs. Please open an issue with your macOS version.

**How do I quit it?**
Right-click the open panel and choose **Quitter**, or run `pkill -x IleDelbe`.

**Why is the interface in French?**
It started as a personal project. Localization is welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Contributing

Bug reports, ideas and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) to get started, and see [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Credits

Now Playing access is provided by [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg (ungive) and contributors, under the BSD 3-Clause License. It is included as a git submodule in `Vendor/mediaremote-adapter`, and its license ships inside the app bundle.

## License

ileDelbe is released under the [MIT License](LICENSE).
