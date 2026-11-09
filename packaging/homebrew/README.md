# jean-baptisteAZAN/homebrew-tap

Homebrew tap for [ileDelbe](https://github.com/jean-baptisteAZAN/ileDelbe), a Dynamic Island-style hub for the MacBook notch.

## Install

```sh
brew install --cask jean-baptisteAZAN/tap/iledelbe
```

This is the same as:

```sh
brew tap jean-baptisteAZAN/tap
brew install --cask iledelbe
```

Requirements: a MacBook with a notch (Apple silicon), macOS 15.4 or later.

## Update

```sh
brew update
brew upgrade --cask iledelbe
```

macOS may ask again for Calendar access after an update. See the [ileDelbe FAQ](https://github.com/jean-baptisteAZAN/ileDelbe#faq-and-troubleshooting).

## Uninstall

```sh
brew uninstall --cask iledelbe        # quits the app and removes it
brew uninstall --zap --cask iledelbe  # also removes its preferences
```

## Maintainers: publishing a new version

1. In the ileDelbe repo, bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Run `DEVELOPER_ID_APP="Developer ID Application: …" NOTARY_PROFILE=ileDelbe make release`.
3. Create the GitHub release `v<version>` and attach `build/ileDelbe-<version>.zip`.
4. Paste the cask printed by the script into `Casks/iledelbe.rb` here (it has the new `version` and `sha256`), then check it:

   ```sh
   brew style --cask jean-baptisteAZAN/tap
   brew audit --cask --online jean-baptisteAZAN/tap/iledelbe
   ```

The source template lives in the ileDelbe repo at `packaging/homebrew/iledelbe.rb`.
