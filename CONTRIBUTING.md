# Contributing to ileDelbe

Thanks for your interest! ileDelbe is a small project, so contributions of any size are welcome: bug reports, ideas, docs, code.

## Before you start

- For a bug, open an issue with the **Bug report** template. Include your Mac model and macOS version.
- For a new feature, open an issue with the **Feature request** template first, so we can agree on the idea before you write code.
- Small fixes (typos, obvious bugs) can go straight to a pull request.

## Set up

You need a MacBook with a notch running macOS 15.4 or later, Xcode 16 or later (the full Xcode), and `cmake` (`brew install cmake`).

```sh
git clone --recurse-submodules https://github.com/jean-baptisteAZAN/ileDelbe.git
cd ileDelbe
make test   # run the tests
make run    # build build/IleDelbe.app and launch it
```

Quit a running copy before `make run` (right-click the panel > **Quitter**, or `pkill -x IleDelbe`).

Each `make app` signs the app ad hoc, so macOS may ask again for Calendar access after a rebuild. If the Agenda tab stays empty, remove ileDelbe in System Settings > Privacy & Security > Calendars and open the tab again.

To read the app's logs:

```sh
log stream --predicate 'subsystem == "io.github.ileDelbe"'
```

## Code layout

```
Sources/
  IleDelbeCore/   Pure logic, no UI, fully unit tested
    Notch/        Notch geometry, hover state machine
    NowPlaying/   Adapter stream decoder, commands, playback position
    Timer/        Countdown timer state machine
    Panel/        Default tab and closed layout rules
    Halo/ History/ Agenda/ Files/ Formatting/
  IleDelbe/       The app
    App/          main.swift, AppDelegate, the notch panel and window controller
    Services/     macOS-facing services (EventKit, Spotlight, CoreAudio, halo, timer)
    Views/        SwiftUI views
Tests/IleDelbeCoreTests/   Swift Testing tests for IleDelbeCore
Vendor/mediaremote-adapter git submodule (BSD-3-Clause)
scripts/                   build-adapter.sh, bundle-app.sh, release.sh
```

Guidelines:

- **Put logic in `IleDelbeCore`** when it can be tested without AppKit or SwiftUI, and add tests for it.
- **Keep views pure.** Views take plain values and closures, not services, and have `#Preview`s with sample data. Services stay in `NotchRootView`.
- **No idle work.** Timers and animations run only while visible or needed (for example, the equalizer pauses when nothing plays).
- Swift 6 with strict concurrency: keep UI code on the main actor.

## User interface copy

The app's interface is in **French** for now (*Musique*, *Minuteur*, *Rejoindre*, ...). Keep new UI strings in French and consistent with the existing ones. Code, comments, commit messages, issues and docs are in English.

Localization (for example an English UI) would be a welcome contribution: please open an issue first to discuss the approach.

## README images

The images in `docs/assets` are generated from the real views with sample data. If you change how a view looks, run:

```sh
make readme-assets
```

and commit the updated PNGs. Never use real personal data in samples.

## Pull requests

- Branch from `main` and keep each pull request focused on one change.
- Run `make test` before you push. The CI runs it too.
- Use clear commit messages, ideally [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, ...).
- For UI changes, add a screenshot or a short screen recording.
- Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-visible changes.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
