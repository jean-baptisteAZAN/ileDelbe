# ileDelbe

ileDelbe is a native macOS agent app that turns the MacBook notch into a hover media panel, like the iPhone Dynamic Island.

- While something plays, the notch grows small "wings": the artwork on the left and an animated equalizer on the right.
- Hover the notch to open the panel. It shows the artwork, title, artist, play/pause, previous, next, a seek bar and a system volume slider.
- It follows whatever macOS treats as "Now Playing" (Spotify, Music, a YouTube tab in the browser, and so on).
- The panel never takes focus, and clicks outside the visible shape go to the menu bar as usual.

### v2: the notch as a hub

- **Colored halo.** The average color of the current artwork tints a soft glow around the closed notch while music plays, a stronger glow under the open panel, the big artwork's shadow and the seek bar. Grey or very dark artwork gives no glow.
- **Tabs.** The open panel has four tabs: **Musique**, **Minuteur**, **Agenda** and **Fichiers**. It opens on Minuteur if a timer rang and you have not seen it yet, else on Musique if something plays, else on the last tab you picked. When an event starts within 60 minutes, "<title> dans N min" shows at the right of the tab bar.
- **Musique.** Everything from v1, plus the last 3 tracks you listened to.
- **Minuteur.** One timer at a time, started from the panel (5, 10 or 25 min), with +1 min, Pause/Reprendre and Arrêter. When it ends, macOS plays the "Glass" sound and the notch turns orange until you hover it (it clears by itself after 60 s). The timer survives a relaunch; one that expired while the app was closed is dropped silently.
- **Bubble.** When a timer runs and music plays, the timer moves to a small bubble at the right of the notch (ring + mm:ss), like two iPhone Live Activities. Hover the bubble to open the panel on Minuteur.
- **Agenda.** The next 2 events of the next 24 hours from all your macOS calendars (all-day events are skipped), with a **Rejoindre** button for Google Meet, Zoom and Microsoft Teams links.
- **Fichiers.** Your 3 most recently used files, as in Finder's Recents. Click to open, or drag a file out of the panel into another app.

## Permissions

- **Calendar.** macOS asks for Calendar access the first time you open the Agenda tab, never before. If you refuse, the tab offers **Ouvrir les Réglages** (System Settings > Privacy & Security > Calendars).
- **Files.** The Fichiers tab uses Spotlight. macOS may ask once for access to folders such as Desktop, Documents or Downloads when the app reads a recent file's icon or opens it.
- **Development builds.** `make app` signs the app ad hoc. macOS ties permissions to the signature, so after a rebuild it may ask again (or show the old grant as stale in System Settings). Remove the old entry and grant it again if the Agenda tab stays empty.

## Requirements

- A MacBook with a notch, running **macOS 15.4 or later**. External screens and Macs without a notch are not supported.
- Xcode 16 or later (full Xcode, not only the command line tools: the SwiftUI previews need its macro plugins).
- `cmake` to build the vendored adapter (`brew install cmake`).

## Build and run

```sh
git submodule update --init
make test   # run the test suite
make app    # build build/IleDelbe.app
make run    # build and launch the app
```

The app has no Dock icon and no menu bar. To quit, open the panel, right-click it and choose **Quitter**. You can also run `pkill -x IleDelbe`.

## Known risk

macOS 15.4 closed the private `MediaRemote` framework to third-party apps. ileDelbe reads Now Playing through [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), a workaround that runs a script with the system `/usr/bin/perl`. Apple may break this in a future macOS release. If the adapter is missing or fails, ileDelbe keeps running as a plain notch and logs one error (`log stream --predicate 'subsystem == "io.github.ileDelbe"'`).

## Credits

Now-playing access is provided by [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg (ungive) and contributors, under the BSD 3-Clause License. It is vendored in `Vendor/mediaremote-adapter` with its license.

## License

MIT
