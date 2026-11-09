# ileDelbe

ileDelbe is a native macOS agent app that turns the MacBook notch into a hover media panel: hover the notch to see and control what is playing.

## Build

```sh
git submodule update --init
make test   # run the test suite
make app    # build build/IleDelbe.app
make run    # build and launch the app
```

Building the vendored adapter requires `cmake` (`brew install cmake`).

## Credits

Now-playing access is provided by [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by ungive.

## License

MIT
