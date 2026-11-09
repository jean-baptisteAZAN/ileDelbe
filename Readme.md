# ileDelbe

ileDelbe is a native macOS agent app that turns the MacBook notch into a hover media panel, like the iPhone Dynamic Island.

- While something plays, the notch grows small "wings": the artwork on the left and an animated equalizer on the right.
- Hover the notch to open the panel. It shows the artwork, title, artist, play/pause, previous, next, a seek bar and a system volume slider.
- It follows whatever macOS treats as "Now Playing" (Spotify, Music, a YouTube tab in the browser, and so on).
- The panel never takes focus, and clicks outside the visible shape go to the menu bar as usual.

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
