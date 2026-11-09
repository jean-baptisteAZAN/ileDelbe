# ileDelbe v1 (notch media player) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS agent app that turns the MacBook notch into a hover-to-expand media panel driven by the system Now Playing session.

**Architecture:** SwiftPM package with two targets. `IleDelbeCore` (library, no AppKit UI) holds all pure, unit-tested logic: adapter JSON parsing and diff merging, command encoding, position interpolation, notch geometry, hover state machine, time formatting. `IleDelbe` (executable) holds the side-effectful shells: adapter process runner, CoreAudio volume, `NSPanel` window, SwiftUI views. A shell script bundles the executable plus the vendored `mediaremote-adapter` into `build/IleDelbe.app`.

**Tech Stack:** Swift 6.3, SwiftPM (tools 6.0), SwiftUI + AppKit, CoreAudio, Swift Testing (`import Testing`), `mediaremote-adapter` (BSD-3, git submodule, built with cmake). Dev machine: macOS 26.2, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-11-09-notch-media-design.md`

## Global Constraints

- Target: MacBook with notch, macOS 15.4+ → `platforms: [.macOS(.v15)]`.
- Agent app: `LSUIElement = YES`, no Dock icon, no menu bar of its own. Quit = right-click on panel → "Quitter".
- Bundle id: `io.github.ileDelbe` (builder's call). App name: `ileDelbe`.
- License MIT. No code copied from GPL projects (boring.notch etc.). Vendored adapter keeps its BSD-3 LICENSE.
- Never activate the app or take key focus. Window must not block menu bar clicks outside the visible shape.
- Idle CPU ~0 %: no timers/animations running when nothing plays or panel is closed and paused.
- Hover delays: open after **0.15 s** of continuous hover, close **0.30 s** after pointer leaves.
- Now Playing source: `/usr/bin/perl <Resources>/mediaremote-adapter.pl <Resources>/MediaRemoteAdapter.framework stream --micros --debounce=50`. Commands: `send 2` toggle, `send 4` next, `send 5` previous, `seek <micros>`.
- If the adapter exits non-zero: stop, never relaunch automatically, app shows nothing (README of adapter: non-zero exit is fatal).

## Review Focus

1. Adapter missing or exits non-zero at launch → no crash, no relaunch loop, notch stays plain. Test in Task 5.
2. Garbage / partial JSON lines, or one JSON line split across two pipe reads → ignored or reassembled, never crash. Tests in Tasks 2 and 5.
3. Source with no duration (YouTube live, some web players) → progress bar disabled, interpolated position not clamped to 0. Tests in Tasks 3 and 9.
4. Pointer crossing the notch quickly to reach a menu → panel must not open. Test in Task 7.
5. Screen config changes (lid closed with external display, resolution change, no notch) → geometry recomputed or window hidden. Test in Task 6 + manual check in Task 10.

---

### Task 1: Repo, package skeleton, vendored adapter, app bundling

**Files:**
- Create: `Package.swift`, `Sources/IleDelbeCore/IleDelbeCore.swift`, `Sources/IleDelbe/main.swift`, `Tests/IleDelbeCoreTests/SmokeTests.swift`
- Create: `Resources/Info.plist`, `scripts/build-adapter.sh`, `scripts/bundle-app.sh`, `Makefile`
- Create: `.gitignore` (`.build/`, `build/`, `Vendor/mediaremote-adapter/build/`, `.DS_Store`), `LICENSE` (MIT, "Copyright (c) 2026 Jean-Baptiste Azan")
- Modify: `Readme.md` (already exists, keep this exact filename — FS is case-insensitive; replace "## Hello" with one paragraph + build commands + credit to mediaremote-adapter)
- Git repo already initialized, remote `origin` = `git@github.com:jean-baptisteAZAN/ileDelbe.git` (public), spec + plan already committed on `main`.
- Submodule: `Vendor/mediaremote-adapter` → `https://github.com/ungive/mediaremote-adapter`

**Interfaces:**
- Produces: `make test` (runs `swift test`), `make app` (builds `build/IleDelbe.app`), `make run` (app + `open build/IleDelbe.app`). Bundle layout: `Contents/MacOS/IleDelbe`, `Contents/Info.plist`, `Contents/Resources/mediaremote-adapter.pl`, `Contents/Resources/MediaRemoteAdapter.framework`.

- [ ] **Step 1:** Add `.gitignore` and `LICENSE` (repo already exists).
- [ ] **Step 2:** `Package.swift`: tools 6.0, `platforms: [.macOS(.v15)]`, library target `IleDelbeCore`, executable target `IleDelbe` depending on it, test target `IleDelbeCoreTests`. `main.swift` prints `"ileDelbe"` for now.
- [ ] **Step 3:** Smoke test `@Test func coreLinks() { #expect(IleDelbeCore.version == "0.1.0") }` with `public enum IleDelbeCore { public static let version = "0.1.0" }`. Run `swift test` → PASS.
- [ ] **Step 4:** `git submodule add https://github.com/ungive/mediaremote-adapter Vendor/mediaremote-adapter`. `scripts/build-adapter.sh`: if `cmake` missing, print `brew install cmake` and exit 1; else `cmake -S Vendor/mediaremote-adapter -B Vendor/mediaremote-adapter/build && cmake --build Vendor/mediaremote-adapter/build`.
- [ ] **Step 5:** Verify adapter works on this Mac: play something in Spotify, run `/usr/bin/perl Vendor/mediaremote-adapter/bin/mediaremote-adapter.pl "$PWD/Vendor/mediaremote-adapter/build/MediaRemoteAdapter.framework" get --micros --no-artwork`. Expected: one JSON object with `title`, `playing`, `durationMicros`. **If it prints `null` or errors while media plays, stop and report — the whole approach depends on it.** Save that JSON (artwork stripped) to `Tests/IleDelbeCoreTests/Fixtures/get-sample.json` for Task 2.
- [ ] **Step 6:** `Resources/Info.plist`: `CFBundleIdentifier io.github.ileDelbe`, `CFBundleName ileDelbe`, `CFBundleExecutable IleDelbe`, `CFBundlePackageType APPL`, `CFBundleShortVersionString 0.1.0`, `LSMinimumSystemVersion 15.4`, `LSUIElement true`, `NSHighResolutionCapable true`.
- [ ] **Step 7:** `scripts/bundle-app.sh`: `swift build -c release`, assemble layout above into `build/IleDelbe.app` (copy `.pl` from `Vendor/mediaremote-adapter/bin/`, framework from adapter build dir), `codesign --force --deep -s - build/IleDelbe.app`. `Makefile` targets `test`, `adapter`, `app` (depends on `adapter`), `run`, `clean`.
- [ ] **Step 8:** Run `make app` → `build/IleDelbe.app/Contents/Resources/MediaRemoteAdapter.framework` exists; `make test` → PASS.
- [ ] **Step 9:** Commit `chore: scaffold package, vendor mediaremote-adapter, bundling`.

### Task 2: Now Playing model, stream parsing, diff merging

**Files:**
- Create: `Sources/IleDelbeCore/NowPlaying/NowPlayingInfo.swift`, `Sources/IleDelbeCore/NowPlaying/AdapterStreamDecoder.swift`
- Test: `Tests/IleDelbeCoreTests/AdapterStreamDecoderTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct NowPlayingInfo: Equatable, Sendable {
      public var bundleIdentifier: String
      public var title: String
      public var artist: String?
      public var album: String?
      public var isPlaying: Bool
      public var duration: TimeInterval?        // seconds, nil if absent or <= 0
      public var elapsed: TimeInterval?         // seconds at `timestamp`
      public var timestamp: Date?
      public var playbackRate: Double           // default 1.0 when absent
      public var artworkData: Data?             // decoded from base64
  }
  public struct AdapterStreamDecoder {
      public init()
      /// Feed one stdout line. Returns current merged info, or nil when nothing is playing / line ignored.
      public mutating func consume(line: String) -> NowPlayingInfo?
      public private(set) var current: NowPlayingInfo?
  }
  ```
- Mapping: `durationMicros`, `elapsedTimeMicros` → seconds (÷1_000_000); `timestampEpochMicros` → `Date(timeIntervalSince1970:)`; `artworkData` base64 → `Data`.

- [ ] **Step 1: Failing tests**
  - `fullPayloadParses`: line `{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Song","artist":"Art","playing":true,"durationMicros":200000000,"elapsedTimeMicros":5000000,"timestampEpochMicros":1700000000000000,"playbackRate":1}}` → title `"Song"`, `duration == 200`, `elapsed == 5`, `isPlaying`, `timestamp == Date(timeIntervalSince1970: 1_700_000_000)`.
  - `diffMergesIntoLast`: full payload then `{"type":"data","diff":true,"payload":{"playing":false}}` → `isPlaying == false`, title still `"Song"`.
  - `diffNullRemovesKey`: full payload then diff `{"artist":null}` → `artist == nil`.
  - `emptyPayloadMeansNothingPlaying`: non-diff `payload: {}` → returns nil, `current == nil`.
  - `garbageLineIgnored`: `"not json"` and `"{\"type\":\"data\""` → returns previous `current` unchanged, no crash.
  - `zeroDurationBecomesNil`: `durationMicros: 0` → `duration == nil`.
  - `artworkDecoded`: `"artworkData":"AQID"` → `Data([1,2,3])`.
  - `realFixtureParses`: decode `Fixtures/get-sample.json` wrapped as non-diff envelope → non-nil, non-empty title (fixture via `Bundle.module`; add `resources: [.copy("Fixtures")]` to test target).
- [ ] **Step 2:** `swift test --filter AdapterStreamDecoderTests` → FAIL (types undefined).
- [ ] **Step 3:** Implement. Keep the raw merged payload as `[String: Any]` (via `JSONSerialization`) inside the decoder, apply diff (`NSNull` → remove key), then map to `NowPlayingInfo`. Payload missing `title` or `bundleIdentifier` → nil.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(core): parse mediaremote-adapter stream`.

### Task 3: Playback position interpolation and time formatting

**Files:**
- Create: `Sources/IleDelbeCore/NowPlaying/PlaybackPosition.swift`, `Sources/IleDelbeCore/Formatting/TimeFormat.swift`
- Test: `Tests/IleDelbeCoreTests/PlaybackPositionTests.swift`, `Tests/IleDelbeCoreTests/TimeFormatTests.swift`

**Interfaces:**
- Consumes: `NowPlayingInfo` (Task 2).
- Produces:
  ```swift
  extension NowPlayingInfo {
      public func position(at now: Date) -> TimeInterval?   // nil if elapsed or timestamp nil
      public var canSeek: Bool                              // duration != nil
  }
  public enum TimeFormat { public static func string(_ seconds: TimeInterval) -> String }
  ```

- [ ] **Step 1: Failing tests**
  - playing, elapsed 10, timestamp T, rate 1, now T+5 → `15`.
  - paused, same → `10`.
  - rate 2, now T+5 → `20`.
  - duration 12, now T+5 (playing) → clamped `12`.
  - duration nil (live), elapsed 100, now T+50 → `150` (no upper clamp); negative never returned (`now < T` → `elapsed`).
  - `canSeek` false when duration nil.
  - `TimeFormat.string`: `0 → "0:00"`, `65 → "1:05"`, `3600 → "1:00:00"`, `-3 → "0:00"`, `.nan → "0:00"`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement: `elapsed + (isPlaying ? max(0, now - timestamp) * playbackRate : 0)`, clamp to `[0, duration ?? .infinity]`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(core): interpolate playback position, format times`.

### Task 4: Adapter command encoding

**Files:**
- Create: `Sources/IleDelbeCore/NowPlaying/AdapterCommand.swift`
- Test: `Tests/IleDelbeCoreTests/AdapterCommandTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum AdapterCommand: Equatable, Sendable {
      case togglePlayPause, next, previous
      case seek(to: TimeInterval)
      public var arguments: [String]   // appended after script + framework paths
  }
  public struct AdapterPaths: Sendable {
      public let script: URL; public let framework: URL
      public init(script: URL, framework: URL)
      public static func inBundle(_ bundle: Bundle) -> AdapterPaths?   // nil if either resource missing
      public func streamArguments() -> [String]  // [script, framework, "stream", "--micros", "--debounce=50"]
      public func arguments(for: AdapterCommand) -> [String]
  }
  ```

- [ ] **Step 1: Failing tests:** `togglePlayPause.arguments == ["send","2"]`, `next == ["send","4"]`, `previous == ["send","5"]`, `seek(to: 12.5) == ["seek","12500000"]`, `seek(to: -1) == ["seek","0"]`; `streamArguments()` exact array above with `.path` strings; `inBundle` on a bundle without resources → nil.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement (micros = `Int((max(0, t) * 1_000_000).rounded())`). **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(core): encode adapter commands`.

### Task 5: NowPlayingService (adapter process runner)

**Files:**
- Create: `Sources/IleDelbeCore/NowPlaying/LineBuffer.swift`, `Sources/IleDelbeCore/NowPlaying/NowPlayingService.swift` (lives in Core: only needs Foundation + Observation, and that keeps it testable)
- Test: `Tests/IleDelbeCoreTests/LineBufferTests.swift`, `Tests/IleDelbeCoreTests/NowPlayingServiceTests.swift`

**Interfaces:**
- Consumes: `AdapterStreamDecoder` (Task 2), `AdapterPaths`, `AdapterCommand` (Task 4).
- Produces:
  ```swift
  public struct LineBuffer { public init(); public mutating func append(_ data: Data) -> [String] }
  @MainActor @Observable
  public final class NowPlayingService {
      public enum Status: Equatable { case idle, running, unavailable(String) }
      public private(set) var info: NowPlayingInfo?
      public private(set) var status: Status
      public init(executable: URL = URL(fileURLWithPath: "/usr/bin/perl"), paths: AdapterPaths?)
      public func start()            // no-op if already running; .unavailable if paths nil
      public func stop()             // SIGTERM the stream process
      public func send(_ command: AdapterCommand)   // fire-and-forget short process
  }
  ```

- [ ] **Step 1: Failing tests**
  - LineBuffer: `append("a\nb")` → `["a"]`, then `append("c\n")` → `["bc"]`; `append("\n\n")` → `[]` (empty lines dropped); UTF-8 multibyte char split across two appends reassembles.
  - Service with `executable: /bin/sh`, paths pointing to a temp script that `echo`s one full payload line then `sleep 5` → within 2 s `info?.title == "Song"`, `status == .running` (use `paths.streamArguments()` → script runs as `sh <script> <framework> stream ...`; framework URL can be any path).
  - Service with temp script `exit 3` → within 2 s `status == .unavailable(...)`, and after another 1 s the script has been launched exactly once (script appends a line to a temp counter file on each run).
  - `paths: nil` → `start()` sets `.unavailable`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement with `Process` + `Pipe`; `readabilityHandler` feeds `LineBuffer`, hop to `MainActor` to run decoder and assign `info`. `terminationHandler`: status 0 or SIGTERM by us → `.idle`; otherwise `.unavailable("exit \(code)")`, stderr text logged via `os.Logger(subsystem: "io.github.ileDelbe", category: "nowplaying")`. No relaunch. `send` spawns `executable` with `paths.arguments(for:)`, ignores output. Stop the stream on `deinit`/app terminate.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Manual: temporarily make `main.swift` start the service with `AdapterPaths(script:framework:)` pointing at the Vendor build, print `info?.title` on change for 15 s while switching tracks in Spotify and a YouTube tab. Expected: titles follow. Revert the temporary code.
- [ ] **Step 6:** Commit `feat(core): run adapter stream and send commands`.

### Task 6: Notch geometry

**Files:**
- Create: `Sources/IleDelbeCore/Notch/NotchGeometry.swift`
- Test: `Tests/IleDelbeCoreTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct NotchGeometry: Equatable, Sendable {
      public let notch: CGRect        // in screen coordinates (AppKit, origin bottom-left)
      public let closedActive: CGRect // notch widened by `closedActiveWing` each side
      public let expanded: CGRect     // top-centered, size `expandedSize`
      public static let closedActiveWing: CGFloat = 36
      public static let expandedSize = CGSize(width: 440, height: 170)
      /// nil when screen has no notch (aux areas nil or safe top inset 0)
      public static func make(screenFrame: CGRect, safeAreaTop: CGFloat,
                              auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) -> NotchGeometry?
  }
  ```
  (Sizes are starting values; the builder may tune them in Task 10.)

- [ ] **Step 1: Failing tests** (14" MBP-like values: screen `(0,0,1512,982)`, safeTop `32`, left `(0,950,662,32)`, right `(850,950,662,32)`):
  - `notch == CGRect(x:662, y:950, width:188, height:32)`.
  - `closedActive == CGRect(x:626, y:950, width:260, height:32)`.
  - `expanded == CGRect(x:536, y:812, width:440, height:170)` (centered on notch midX 756, top flush with screen top).
  - Screen with non-zero origin (`(1512,0,1512,982)`, areas shifted by 1512) → rects shifted by 1512.
  - `auxiliaryTopLeft == nil` → nil; `safeAreaTop == 0` → nil.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): compute notch geometry`.

### Task 7: Hover state machine

**Files:**
- Create: `Sources/IleDelbeCore/Notch/HoverStateMachine.swift`
- Test: `Tests/IleDelbeCoreTests/HoverStateMachineTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct HoverStateMachine: Sendable {
      public static let openDelay: TimeInterval = 0.15
      public static let closeDelay: TimeInterval = 0.30
      public private(set) var isOpen: Bool
      public init()
      /// `inTrigger`: pointer inside notch rect when closed, inside expanded rect when open.
      public mutating func update(inTrigger: Bool, now: TimeInterval)
      /// Next time `update` must be called even without mouse movement (pending open/close), nil if none.
      public var nextDeadline: TimeInterval? { get }
  }
  ```

- [ ] **Step 1: Failing tests**
  - enter at 0, still inside at 0.10 → closed; at 0.16 → open.
  - quick pass: enter at 0, leave at 0.08, update at 0.30 → closed (Review Focus #4).
  - open, leave at 1.0, update 1.2 → open; update 1.31 → closed.
  - open, leave at 1.0, re-enter at 1.2, update 2.0 → open (close cancelled).
  - `nextDeadline` after entering at 0 == 0.15; after open and leaving at 1.0 == 1.30; when stable → nil.
- [ ] **Step 2:** FAIL. **Step 3:** Implement (track `pendingSince: TimeInterval?`). **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): hover open/close state machine`.

### Task 8: Volume service (CoreAudio)

**Files:**
- Create: `Sources/IleDelbe/Services/VolumeService.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor @Observable
  final class VolumeService {
      private(set) var volume: Float      // 0...1
      private(set) var isSettable: Bool
      init()
      func set(_ value: Float)            // clamps to 0...1; no-op when !isSettable
  }
  ```

- [ ] **Step 1:** Implement against `kAudioHardwarePropertyDefaultOutputDevice` and `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` (scope output, element main). `isSettable` from `AudioObjectIsPropertySettable`. Register listeners for default-device change (re-bind) and volume change (update `volume`); deliver on main queue.
- [ ] **Step 2:** Manual check via temporary `main.swift`: print volume, set 0.3, confirm macOS volume HUD/menu shows ~30 %; change volume with keyboard keys, confirm printed value follows; switch to an output without volume control (e.g. HDMI if available) → `isSettable == false`. Revert temporary code.
- [ ] **Step 3:** `swift build` → succeeds with no warnings under Swift 6 concurrency.
- [ ] **Step 4:** Commit `feat: system volume service`.

### Task 9: SwiftUI views

**Files:**
- Create: `Sources/IleDelbe/Views/NotchShape.swift`, `Sources/IleDelbe/Views/EqualizerView.swift`, `Sources/IleDelbe/Views/ClosedActivityView.swift`, `Sources/IleDelbe/Views/ExpandedPlayerView.swift`, `Sources/IleDelbe/Views/ScrubberView.swift`, `Sources/IleDelbe/Views/NotchRootView.swift`
- Create: `Sources/IleDelbe/Views/NotchViewModel.swift`

**Interfaces:**
- Consumes: `NowPlayingService`, `NowPlayingInfo.position(at:)`, `canSeek`, `TimeFormat`, `AdapterCommand`, `VolumeService`, `NotchGeometry`.
- Produces:
  ```swift
  @MainActor @Observable final class NotchViewModel {
      var isOpen: Bool
      var geometry: NotchGeometry?
      let nowPlaying: NowPlayingService
      let volume: VolumeService
      init(nowPlaying: NowPlayingService, volume: VolumeService)
  }
  struct NotchRootView: View { init(model: NotchViewModel) }
  ```

- [ ] **Step 1:** `NotchShape`: black, flat top, bottom corners radius 10 closed / 22 open, animatable radius.
- [ ] **Step 2:** `NotchRootView` fills the window (sized to `expanded`), draws the shape at top-center with frame = notch / closedActive / expanded size depending on state: open → expanded; closed + `info?.isPlaying == true` → closedActive; else notch size. Animate size with `.spring(response: 0.35, dampingFraction: 0.8)`. Right-click `.contextMenu { Button("Quitter") { NSApp.terminate(nil) } }` on the shape.
- [ ] **Step 3:** `ClosedActivityView`: artwork 20×20 rounded 4 on the left wing, `EqualizerView` (4 bars) on the right wing. `EqualizerView` animates only while `isPlaying` (bars static otherwise; use `TimelineView(.animation(paused: !isPlaying))`).
- [ ] **Step 4:** `ExpandedPlayerView`: artwork 64×64, title (1 line, bold) / artist (1 line, secondary), buttons `backward.fill` / `playpause.fill` (`play.fill` vs `pause.fill` by state) / `forward.fill` sending `.previous`, `.togglePlayPause`, `.next`; `ScrubberView`; volume `Slider` with `speaker.fill` / `speaker.wave.3.fill`, `.disabled(!volume.isSettable)`. No info → centered secondary text "Rien en lecture".
- [ ] **Step 5:** `ScrubberView`: `TimelineView(.periodic(from: .now, by: 0.5))` only while open and playing; shows `TimeFormat` elapsed / duration; drag updates a local value and sends `.seek(to:)` on release. `!canSeek` → shows elapsed only, bar hidden (Review Focus #3).
- [ ] **Step 6:** `swift build` → succeeds. Add `#Preview`s for closed-playing, open-playing, open-live-stream (no duration), open-nothing with a stubbed `NowPlayingInfo` — previews must render in Xcode (`open Package.swift`).
- [ ] **Step 7:** Commit `feat: notch SwiftUI views`.

### Task 10: Notch window, app wiring, end-to-end verification

**Files:**
- Create: `Sources/IleDelbe/App/NotchPanel.swift`, `Sources/IleDelbe/App/NotchWindowController.swift`, `Sources/IleDelbe/App/AppDelegate.swift`
- Modify: `Sources/IleDelbe/main.swift`, `Readme.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the running app.

- [ ] **Step 1:** `NotchPanel: NSPanel`: `styleMask [.borderless, .nonactivatingPanel]`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `level = .mainMenu + 3`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, `canBecomeKey`/`canBecomeMain` → `false`, `hidesOnDeactivate = false`. Content = `NSHostingView(rootView: NotchRootView(model:))`.
- [ ] **Step 2:** `NotchWindowController`:
  - Picks the screen where `NotchGeometry.make(...)` is non-nil (prefer `NSScreen.screens.first { $0.localizedName.contains("Built-in") }` fallback any non-nil). None → `orderOut` and set `model.geometry = nil`.
  - Window frame = `geometry.expanded`; `ignoresMouseEvents = !isOpen` (closed state never intercepts clicks).
  - Mouse: `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` + local monitor for the same → `hover.update(inTrigger:now:)` using `NSEvent.mouseLocation` against `notch` (closed) or `expanded` (open), `now = ProcessInfo.processInfo.systemUptime`. If `nextDeadline != nil`, schedule one `DispatchWorkItem` at that deadline (cancel previous); no repeating timers.
  - Recompute geometry on `NSApplication.didChangeScreenParametersNotification` (Review Focus #5).
- [ ] **Step 3:** `AppDelegate`: `NSApp.setActivationPolicy(.accessory)`; create `NowPlayingService(paths: .inBundle(.main))`, `start()`; `VolumeService()`; model; controller. `applicationWillTerminate` → `nowPlaying.stop()`. `main.swift`: standard `NSApplication.shared` + delegate + `run()`.
- [ ] **Step 4:** `make test` → all PASS. `make run`.
- [ ] **Step 5: Manual verification checklist** (record result of each in the commit body):
  1. Spotify playing → closed notch shows mini artwork + animated equalizer; pause → back to plain notch, equalizer stops.
  2. Hover notch → opens after ~0.15 s; leave → closes after ~0.3 s; quick swipe across notch to reach a menu → does not open.
  3. Controls: play/pause, next, previous work for Spotify and for a YouTube tab in the browser; scrubber drag seeks; YouTube live → no progress bar.
  4. Volume slider moves system volume; keyboard volume keys move the slider.
  5. Focus: typing in TextEdit, hover and click panel buttons → typing continues in TextEdit, ileDelbe never appears active (menu bar app name unchanged).
  6. Menu bar: click menu items/icons left and right of the notch → work normally, panel closed or open.
  7. Full-screen app (e.g. Safari full screen) → panel works; revealing the menu bar is not blocked.
  8. Idle CPU: nothing playing, panel closed → `top -l 3 -pid $(pgrep IleDelbe) -stats cpu` ≈ 0.0 %.
  9. Change display resolution (Displays settings) → notch still aligned; close lid with external screen (if available) → nothing shown, no crash.
  10. Rename `Resources/mediaremote-adapter.pl` inside the bundle and relaunch → app runs, plain notch, no crash, no relaunch loop (`log stream --predicate 'subsystem == "io.github.ileDelbe"'` shows one error).
- [ ] **Step 6:** README: what it is, requirements (macOS 15.4+, notch, cmake), `make run`, how to quit, credit + license of mediaremote-adapter, known risk (Apple may break Now Playing access).
- [ ] **Step 7:** Commit `feat: notch window and app wiring (v1)`.
