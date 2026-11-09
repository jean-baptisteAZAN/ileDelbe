# ileDelbe v2 (Stack hub) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the v1 notch media panel into a tabbed hub (Music, Timer, Agenda, Files) with an artwork-colored halo and a detached timer bubble.

**Architecture:** Same split as v1. New pure logic goes into `IleDelbeCore` with Swift Testing tests: halo color, countdown timer, listening history, tab/closed-layout rules, meeting links, agenda filtering, recent-file filtering, relative time, geometry. Side-effectful services (timer ticking + sound, history persistence, artwork color, EventKit, Spotlight) and views live in the `IleDelbe` app target and are wired through `NotchViewModel` and `NotchWindowController`.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftUI + AppKit, CoreImage (`CIAreaAverage`), EventKit, Foundation `NSMetadataQuery`, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-09-notch-stack-v2-design.md` (v1 spec still applies: `docs/superpowers/specs/2026-11-09-notch-media-design.md`). Mockup: https://claude.ai/artifact/GNrrJyn1E7SWrgvnoVALik (direction B).

## Global Constraints

- macOS 15.4+, `platforms: [.macOS(.v15)]`, Swift 6 language mode, `swift build` warning-free, `make test` green. Building requires full Xcode 16+.
- Agent app (`LSUIElement`), never activates or takes key focus. Exceptions: "Rejoindre" and opening a file activate the target app on purpose.
- Clicks pass through outside drawn shapes (closed state: `ignoresMouseEvents = true`), bubble included.
- Idle CPU ~0 %: timer ticks at 1 Hz only while running or ringing; agenda minute refresh only while an event starts within 60 min; no polling loops; equalizer stays at 15 fps.
- Hover delays unchanged: open 0.15 s, close 0.30 s, deadline work items at `nextDeadline + 0.01 s`.
- Expanded panel size **548×236** (was 440×170). Bubble: **76×32**, gap **8** to the right of `closedActive`.
- Tabs, in order: Musique, Minuteur, Agenda, Fichiers. Timer presets **5, 10, 25 min**; **+1 min**; one timer at a time; ringing → system sound **"Glass"**, orange alert until hover/click, auto-clear after **60 s**.
- Agenda: next **2** events within **24 h**, all calendars, no all-day events; info line "<titre> dans N min" only when an event starts within **60 min**; "Rejoindre" for Google Meet / Zoom / Microsoft Teams links.
- Files: **3** most recent by `kMDItemLastUsedDate` under home; exclude directories, apps, hidden paths, `~/Library`.
- History: max **20** entries persisted in `UserDefaults`, no consecutive duplicate, shows **3**, excludes current track, not clickable.
- Calendar permission requested on first Agenda tab open only; `NSCalendarsFullAccessUsageDescription` in Info.plist.
- Copy (French, verbatim): tab labels above; "Écoutés récemment"; "Récents"; "Rejoindre"; "Accès au calendrier refusé"; "Ouvrir les Réglages"; "Aucun événement dans les prochaines 24 h"; "Aucun fichier récent"; "Rien en lecture"; "Minuteur terminé"; "OK"; "Pause"; "Reprendre"; "Arrêter"; "+1 min".
- Bundle id `io.github.ileDelbe`; logger subsystem `io.github.ileDelbe`.

## Review Focus

1. Calendar access not determined or denied → no prompt at launch, no info line, Agenda tab shows "Accès au calendrier refusé" + "Ouvrir les Réglages" when denied. Tests in Task 4 (info line nil without events) + manual check in Task 12.
2. Timer survives sleep/relaunch via absolute end date; expired while app closed → idle, no alert. Tests in Task 2.
3. Missing, dark or greyscale artwork → no glow, white progress bar. Tests in Task 1.
4. Fewer than 3 (or zero) recent files, files in hidden / `~/Library` / `.app` paths → excluded, empty state shown. Tests in Task 5.
5. Media pauses while bubble is shown → bubble retracts, timer moves to the wings; ringing overrides everything. Tests in Task 4 (`ClosedLayout`).

---

### Task 1: Halo color (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Halo/HaloColor.swift`
- Test: `Tests/IleDelbeCoreTests/HaloColorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct RGBColor: Equatable, Sendable { public var r, g, b: Double; public init(r: Double, g: Double, b: Double) }  // 0...1
  public enum HaloColor {
      public static let minSaturation = 0.15, minBrightness = 0.12
      public static let boostedSaturation = 0.55, boostedBrightness = 0.75
      /// nil when the average is too grey (S < minSaturation) or too dark (B < minBrightness);
      /// otherwise same hue with S = max(S, boostedSaturation), B = max(B, boostedBrightness).
      public static func glow(fromAverage c: RGBColor) -> RGBColor?
  }
  ```

- [ ] **Step 1: Failing tests**
  - `greyIsNil`: `(0.5,0.5,0.5)` → nil. `nearBlackIsNil`: `(0.05,0.02,0.02)` → nil.
  - `darkRedBoosted`: `(0.4,0.1,0.1)` → hue stays red (r is max channel, g≈b), brightness (max channel) ≈ 0.75 ±0.01, saturation ≥ 0.55.
  - `vividUnchanged`: `(1.0,0.35,0.3)` (S≈0.7, B=1) → equal to input ±0.001.
  - `hueKept`: input `(0.2,0.6,0.9)` → output max channel is b, min channel is r.
- [ ] **Step 2:** `swift test --filter HaloColorTests` → FAIL.
- [ ] **Step 3:** Implement with RGB↔HSB conversion (no AppKit).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(core): halo color from artwork average`.

### Task 2: Countdown timer (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Timer/CountdownTimer.swift`
- Test: `Tests/IleDelbeCoreTests/CountdownTimerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct CountdownTimer: Equatable, Codable, Sendable {
      public enum State: Equatable, Codable, Sendable {
          case idle
          case running(end: Date, total: TimeInterval)
          case paused(remaining: TimeInterval, total: TimeInterval)
          case ringing(since: Date)
      }
      public static let presets: [TimeInterval] = [300, 600, 1500]
      public static let ringingAutoClear: TimeInterval = 60
      public private(set) var state: State
      public init()
      public mutating func start(duration: TimeInterval, now: Date)   // replaces any current timer
      public mutating func addMinute(now: Date)      // running: end += 60, total += 60; paused: +60 both; else no-op
      public mutating func pause(now: Date)          // running → paused
      public mutating func resume(now: Date)         // paused → running(end: now+remaining)
      public mutating func stop()                    // → idle
      public mutating func acknowledge()             // ringing → idle
      /// running past end → ringing(since: end); ringing older than 60 s → idle. Returns true if it just started ringing.
      @discardableResult public mutating func tick(now: Date) -> Bool
      /// For relaunch: running already past end, or ringing → idle (no alert). Paused kept.
      public mutating func restoreAfterLaunch(now: Date)
      public func remaining(at now: Date) -> TimeInterval   // 0 when idle/ringing
      public func progress(at now: Date) -> Double          // remaining/total in 0...1, 0 when idle/ringing
      public var isActive: Bool    // running or paused
      public var isRinging: Bool
  }
  ```

- [ ] **Step 1: Failing tests** (T = `Date(timeIntervalSince1970: 1_000_000)`):
  - start(300, T) → `remaining(at: T+60) == 240`, `progress(at: T+60) == 0.8`.
  - pause at T+60, resume at T+500 → `remaining(at: T+500) == 240`.
  - addMinute while running at T → `remaining(at: T) == 360`, progress 1.0.
  - tick(T+299) → false, still running; tick(T+301) → true, `state == .ringing(since: T+300)`; tick(T+361) → idle.
  - acknowledge while ringing → idle. stop while paused → idle.
  - **Sleep:** start(300, T); first tick at T+4000 → returns true, state `ringing(since: T+300)`; second tick at T+4000 → returns false, state idle (ringing older than 60 s).
  - restoreAfterLaunch: running with end T+300 at now T+400 → idle; paused → unchanged; running with end in future → unchanged; ringing → idle.
  - Codable round-trip of running state via `JSONEncoder`/`JSONDecoder` equals original.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): countdown timer state machine`.

### Task 3: Listening history (Core)

**Files:**
- Create: `Sources/IleDelbeCore/History/ListeningHistory.swift`
- Test: `Tests/IleDelbeCoreTests/ListeningHistoryTests.swift`

**Interfaces:**
- Consumes: `NowPlayingInfo` (v1).
- Produces:
  ```swift
  public struct ListeningEntry: Equatable, Codable, Sendable {
      public let title: String; public let artist: String?; public let startedAt: Date; public let thumbnail: Data?
  }
  public struct ListeningHistory: Equatable, Codable, Sendable {
      public static let maxEntries = 20
      public private(set) var entries: [ListeningEntry]   // newest first
      public init(entries: [ListeningEntry] = [])
      /// Records a track when it starts playing. Same title+artist as entries[0] → no new entry.
      public mutating func record(title: String, artist: String?, thumbnail: Data?, at: Date)
      /// Newest first, skipping an entry matching `current` (title+artist), at most `limit`.
      public func recent(excluding current: NowPlayingInfo?, limit: Int = 3) -> [ListeningEntry]
  }
  ```

- [ ] **Step 1: Failing tests:** record A, B, C → entries C,B,A; record C again → still 3; record A → A,C,B,A (non-consecutive duplicates allowed); 25 records → 20 entries, newest kept; `recent(excluding: current C)` with entries C,B,A → [B,A]; limit 3 respected; Codable round-trip.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): listening history`.

### Task 4: Panel rules — tabs, closed layout, meeting links, agenda (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Panel/PanelRules.swift`, `Sources/IleDelbeCore/Agenda/AgendaEvent.swift`, `Sources/IleDelbeCore/Agenda/MeetingLink.swift`
- Test: `Tests/IleDelbeCoreTests/PanelRulesTests.swift`, `Tests/IleDelbeCoreTests/AgendaTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum PanelTab: String, CaseIterable, Codable, Sendable { case music, timer, agenda, files }  // display order
  public enum ClosedLayout: Equatable, Sendable { case plain, media, timer, mediaAndBubble, alert }
  public enum PanelRules {
      public static func defaultTab(timerRingingUnseen: Bool, isPlaying: Bool, lastUsed: PanelTab) -> PanelTab
      /// alert if ringing; mediaAndBubble if playing && timerActive; media if playing; timer if timerActive; else plain
      public static func closedLayout(isPlaying: Bool, timerActive: Bool, timerRinging: Bool) -> ClosedLayout
  }
  public struct AgendaEvent: Equatable, Sendable, Identifiable {
      public let id: String; public let title: String; public let start: Date; public let end: Date
      public let isAllDay: Bool; public let colorHex: String?; public let meetingURL: URL?
      public init(id:title:start:end:isAllDay:colorHex:meetingURL:)
  }
  public enum Agenda {
      public static let window: TimeInterval = 86_400, limit = 2, soonThreshold: TimeInterval = 3_600
      /// not all-day, end > now, start < now + window; sorted by start; first `limit`.
      public static func upcoming(_ events: [AgendaEvent], now: Date) -> [AgendaEvent]
      /// "<title> dans N min" (N = ceil minutes, min 1) when 0 < start-now <= 3600; else nil.
      public static func infoLine(_ upcoming: [AgendaEvent], now: Date) -> String?
  }
  public enum MeetingLink {
      /// First https URL found across texts matching meet.google.com/<code>, <sub>.zoom.us/j/<id> or zoom.us/j/<id>,
      /// teams.microsoft.com/l/meetup-join/..., teams.live.com/meet/... ; nil otherwise.
      public static func find(in texts: [String?]) -> URL?
  }
  ```

- [ ] **Step 1: Failing tests**
  - `defaultTab`: (true, true, .files) → .timer; (false, true, .agenda) → .music; (false, false, .agenda) → .agenda.
  - `closedLayout`: ringing beats all → .alert; (playing, active) → .mediaAndBubble; (playing, !active) → .media; (!playing, active) → .timer (Review Focus #5); (!playing, !active) → .plain.
  - `upcoming`: drops all-day, ended, beyond 24 h; keeps an in-progress event; sorts; returns 2.
  - `infoLine`: event at now+12 min titled "Point produit" → "Point produit dans 12 min"; at now+30 s → "… dans 1 min"; at now+61 min → nil; empty → nil; event already started → nil.
  - `MeetingLink`: notes "Lien : https://meet.google.com/abc-defg-hij merci" → that URL; location "https://acme.zoom.us/j/123456789?pwd=x" → that URL; Teams `https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y` → URL; `https://example.com` → nil; `[nil, nil]` → nil; first match wins in text order.
- [ ] **Step 2:** FAIL. **Step 3:** Implement (`NSRegularExpression` or Swift `Regex`). **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): panel tab rules, agenda filtering, meeting links`.

### Task 5: Recent files filter and relative time (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Files/RecentFile.swift`, `Sources/IleDelbeCore/Formatting/RelativeTime.swift`
- Test: `Tests/IleDelbeCoreTests/RecentFilesTests.swift`, `Tests/IleDelbeCoreTests/RelativeTimeTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct RecentFile: Equatable, Sendable, Identifiable {
      public var id: URL { url }
      public let url: URL; public let lastUsed: Date; public let isDirectory: Bool
      public init(url: URL, lastUsed: Date, isDirectory: Bool)
      public var name: String { get }        // lastPathComponent
      public var parentName: String { get }  // localized French for Desktop/Documents/Downloads: "Bureau", "Documents", "Téléchargements"; else parent folder name
  }
  public enum RecentFiles {
      public static let limit = 3
      /// Excludes directories, anything whose path has a component starting with ".", anything under home/Library,
      /// anything inside or being a ".app" bundle; dedupes by URL; sorts by lastUsed desc; first `limit`.
      public static func select(_ candidates: [RecentFile], home: URL) -> [RecentFile]
  }
  public enum RelativeTime {
      /// < 60 s "à l'instant"; < 60 min "il y a N min"; < 24 h "il y a N h"; < 48 h "hier"; else "le d MMM" (fr_FR, e.g. "le 3 nov.").
      public static func string(from date: Date, now: Date) -> String
  }
  ```

- [ ] **Step 1: Failing tests** (home `/Users/test`): keeps 3 newest of 5 valid files; excludes `/Users/test/.config/x.json`, `/Users/test/Library/Caches/y.db`, `/Applications/Foo.app`, `/Users/test/Foo.app/Contents/Info.plist`, a directory; 1 valid file → [it]; none → []; duplicate URL kept once; `parentName` of `/Users/test/Downloads/a.pdf` → "Téléchargements", `/Users/test/Desktop/b.png` → "Bureau", `/Users/test/Projets/c.txt` → "Projets". RelativeTime: +10 s → "à l'instant", +4 min → "il y a 4 min", +2 h → "il y a 2 h", +30 h → "hier", +6 days → "le …" (assert prefix "le ").
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(core): recent files selection, relative time`.

### Task 6: Geometry for v2 (Core)

**Files:**
- Modify: `Sources/IleDelbeCore/Notch/NotchGeometry.swift`, `Tests/IleDelbeCoreTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces: `expandedSize = CGSize(width: 548, height: 236)`; new `public let bubble: CGRect` (width `bubbleWidth = 76`, height = notch height, x = `closedActive.maxX + bubbleGap` with `bubbleGap = 8`, y = notch.minY). Window frame stays `expanded` (bubble lies inside it).

- [ ] **Step 1:** Update tests to the 14" values (screen `(0,0,1512,982)`, safeTop 32, left `(0,950,662,32)`, right `(850,950,662,32)`): `expanded == CGRect(x:482, y:746, width:548, height:236)`; `bubble == CGRect(x:894, y:950, width:76, height:32)`; `expanded.contains(bubble)`; non-zero-origin test shifted accordingly; nil cases unchanged.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** `make test` → all PASS.
- [ ] **Step 5:** Commit `feat(core): v2 panel size and bubble rect`.

### Task 7: Timer and history services (app)

**Files:**
- Create: `Sources/IleDelbe/Services/TimerService.swift`, `Sources/IleDelbe/Services/HistoryService.swift`

**Interfaces:**
- Consumes: `CountdownTimer`, `ListeningHistory`, `NowPlayingService` (v1, `info`).
- Produces:
  ```swift
  @MainActor @Observable final class TimerService {
      private(set) var timer: CountdownTimer
      private(set) var now: Date            // updated each tick, drives UI
      var ringingUnseen: Bool               // set true when ringing starts; view model clears it when the panel shows the timer tab
      init(defaults: UserDefaults = .standard)   // restores from key "timer.v1", calls restoreAfterLaunch
      func start(_ duration: TimeInterval); func addMinute(); func pause(); func resume(); func stop(); func acknowledge()
  }
  @MainActor @Observable final class HistoryService {
      private(set) var history: ListeningHistory
      init(nowPlaying: NowPlayingService, defaults: UserDefaults = .standard)  // key "history.v1"
  }
  ```
- TimerService: one repeating 1 s `Timer` exists only while `isActive || isRinging`, invalidated otherwise. On `tick` returning true → `NSSound(named: "Glass")?.play()`, `ringingUnseen = true`. Persist after every mutation.
- HistoryService: observe `nowPlaying.info` with `withObservationTracking` re-armed after each change (no polling). Record when a track becomes playing and title+artist differs from the last recorded; thumbnail = artwork scaled to 56×56 PNG via `NSImage`/`NSBitmapImageRep`. Persist on change.

- [ ] **Step 1:** Implement both.
- [ ] **Step 2:** Manual check via a temporary `main.swift` block (revert after): start a 5 s timer (`start(5)`) and run the RunLoop 8 s → "Glass" plays, state ringing, `ringingUnseen == true`; relaunch the temp binary → timer idle (expired). Play then skip a Spotify track via `osascript` → history gains entries; `defaults read io.github.ileDelbe` (or the executable's domain) shows `history.v1`. Pause Spotify at the end.
- [ ] **Step 3:** `swift build` warning-free, `make test` green.
- [ ] **Step 4:** Commit `feat: timer and listening history services`.

### Task 8: Artwork halo color service (app)

**Files:**
- Create: `Sources/IleDelbe/Services/HaloService.swift`

**Interfaces:**
- Consumes: `HaloColor.glow(fromAverage:)`, `NowPlayingService.info?.artworkData`.
- Produces:
  ```swift
  @MainActor @Observable final class HaloService {
      private(set) var glow: Color?      // SwiftUI color, nil = no halo
      init(nowPlaying: NowPlayingService)
  }
  ```
- Compute the average with `CIFilter.areaAverage()` over the image extent, rendered into a 1×1 RGBA8 bitmap with a shared `CIContext`, in a detached `Task` (off-main). Cache the last result by artwork `Data` hash; ignore stale results (artwork changed meanwhile). Observe `info` via `withObservationTracking`.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Manual check (temp `main.swift`, revert after): with Spotify playing, print `glow` once computed; switch tracks → value changes; no artwork → nil.
- [ ] **Step 3:** Build warning-free, tests green.
- [ ] **Step 4:** Commit `feat: halo color service from artwork`.

### Task 9: Calendar service (app)

**Files:**
- Create: `Sources/IleDelbe/Services/CalendarService.swift`
- Modify: `Resources/Info.plist` (add `NSCalendarsFullAccessUsageDescription` = "ileDelbe affiche tes prochains rendez-vous dans l'encoche.")

**Interfaces:**
- Consumes: `AgendaEvent`, `Agenda.upcoming`, `Agenda.infoLine`, `MeetingLink.find`.
- Produces:
  ```swift
  @MainActor @Observable final class CalendarService {
      enum Access: Equatable { case notDetermined, granted, denied }
      private(set) var access: Access
      private(set) var upcoming: [AgendaEvent]
      private(set) var infoLine: String?
      init()                            // reads authorization status; does NOT prompt; starts if already granted
      func requestAccessIfNeeded()      // called by the Agenda tab on first appear; prompts only when .notDetermined
      func openPrivacySettings()        // x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars
  }
  ```
- Fetch with `EKEventStore.predicateForEvents(withStart: now, end: now+24h, calendars: nil)`, map to `AgendaEvent` (`meetingURL = MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])`, `colorHex` from `event.calendar.cgColor`). Refresh on `.EKEventStoreChanged`. One-shot `DispatchWorkItem` at the next minute boundary only while `infoLine != nil` or the next event starts within 60 min; also schedule a refresh at the next event's end.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** `make app`, run the bundle with a temporary debug hook that calls `requestAccessIfNeeded()` 2 s after launch (revert after) → macOS shows the Calendar prompt; after allowing, log (`Logger` category `calendar`) the upcoming events and info line. Record what happened in the report (if your session cannot click the prompt, report NEEDS HUMAN and verify the `.denied` path instead by checking `access`).
- [ ] **Step 3:** Build warning-free, tests green.
- [ ] **Step 4:** Commit `feat: calendar service with lazy permission`.

### Task 10: Recent files service (app)

**Files:**
- Create: `Sources/IleDelbe/Services/RecentFilesService.swift`

**Interfaces:**
- Consumes: `RecentFile`, `RecentFiles.select`.
- Produces:
  ```swift
  @MainActor @Observable final class RecentFilesService {
      private(set) var files: [RecentFile]
      init(home: URL = FileManager.default.homeDirectoryForCurrentUser)
      func open(_ file: RecentFile)          // NSWorkspace.shared.open(url)
      func icon(for file: RecentFile) -> NSImage   // NSWorkspace.shared.icon(forFile:)
  }
  ```
- `NSMetadataQuery`, scope `NSMetadataQueryUserHomeScope`, predicate `kMDItemLastUsedDate >= $time.today(-30)` (or a computed date 30 days ago), sort descriptor `kMDItemLastUsedDate` descending. On `.NSMetadataQueryDidFinishGathering` and `.NSMetadataQueryDidUpdate`: `disableUpdates`, map the first 40 results to `RecentFile` (`kMDItemPath`, `kMDItemLastUsedDate`, `kMDItemContentTypeTree` contains `public.folder` → directory), `select`, `enableUpdates`. Query runs for the app's lifetime (Spotlight pushes updates; no polling).

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Manual check (temp hook, revert after): print `files` after gathering; `touch` + `open -a TextEdit` a temp file in `~/Documents`, close it → it appears first within a few seconds.
- [ ] **Step 3:** Build warning-free, tests green.
- [ ] **Step 4:** Commit `feat: recent files service via Spotlight`.

### Task 11: Tabbed panel views, halo, bubble, closed layouts

**Files:**
- Create: `Sources/IleDelbe/Views/TabBarView.swift`, `Sources/IleDelbe/Views/MusicPaneView.swift`, `Sources/IleDelbe/Views/TimerPaneView.swift`, `Sources/IleDelbe/Views/AgendaPaneView.swift`, `Sources/IleDelbe/Views/FilesPaneView.swift`, `Sources/IleDelbe/Views/BubbleView.swift`, `Sources/IleDelbe/Views/TimerRingView.swift`
- Modify: `Sources/IleDelbe/Views/ExpandedPlayerView.swift` (accept `glow: Color?`: artwork shadow + scrubber fill), `Sources/IleDelbe/Views/ClosedActivityView.swift` (layouts), `Sources/IleDelbe/Views/ScrubberView.swift` (fill color)

**Interfaces:**
- Consumes: Core types from Tasks 1–6; services' plain values (views stay pure: values + closures, as in v1).
- Produces (all pure SwiftUI views):
  - `TabBarView(selected: PanelTab, timerActive: Bool, infoLine: String?, onSelect: (PanelTab) -> Void)` — segmented pill, orange dot on Minuteur when `timerActive`, info line right-aligned, secondary.
  - `MusicPaneView(info:, history: [ListeningEntry], glow:, volume:, isVolumeSettable:, onCommand:, onVolume:)` — v1 player left, "Écoutés récemment" column right (190 pt) with up to 3 rows (28 pt thumbnail, title, `HH:mm`).
  - `TimerPaneView(timer: CountdownTimer, now: Date, onStart: (TimeInterval)->Void, onAddMinute:, onPause:, onResume:, onStop:, onAcknowledge:)` — idle: three preset pills "5 min" "10 min" "25 min"; active: `TimerRingView` (104 pt, orange) + "+1 min", "Pause"/"Reprendre", "Arrêter"; ringing: "Minuteur terminé" + "OK".
  - `AgendaPaneView(access:, events: [AgendaEvent], now: Date, onAppear:, onJoin: (URL)->Void, onOpenSettings:)` — denied: "Accès au calendrier refusé" + "Ouvrir les Réglages"; granted & empty: "Aucun événement dans les prochaines 24 h"; else up to 2 cards (color bar, title, "HH:mm – HH:mm", relative start), "Rejoindre" when `meetingURL != nil`.
  - `FilesPaneView(files: [RecentFile], icon: (RecentFile)->NSImage, now: Date, onOpen:, onDragStart: () -> Void)` — header "Récents", 3 cards (icon 30 pt, name, "<parentName> · <RelativeTime>"), tap → `onOpen`, `.onDrag { onDragStart(); return NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }`; empty: "Aucun fichier récent".
  - `BubbleView(timer: CountdownTimer, now: Date)` — black capsule 76×32 with bottom radius 16, `TimerRingView` 16 pt + `mm:ss` orange semibold tabular.
  - `ClosedActivityView(layout: ClosedLayout, artworkData:, isPlaying:, timer:, now:, glow:)` — `.media`: v1 wings; `.timer`: left timer icon, right `mm:ss` orange; `.mediaAndBubble`: media wings (bubble drawn separately); `.alert`: orange "Minuteur terminé" pulse (opacity animation only while `.alert`); `.plain`: nothing.
- Orange = `Color(red: 1, green: 0.62, blue: 0.04)`. Glow modifiers: closed media `shadow(color: glow.opacity(0.9), radius: 11)`; open `shadow(color: glow.opacity(0.8), radius: 35, y: 13)`.

- [ ] **Step 1:** Implement views; add `#Preview`s for each pane (idle/active/ringing timer; agenda denied/empty/two events with one "Rejoindre"; files 3/0; music with/without glow).
- [ ] **Step 2:** `swift build` warning-free, `make test` green.
- [ ] **Step 3:** Commit `feat: tabbed panel views, halo, bubble`.

### Task 12: Integration — model, root view, window controller, verification

**Files:**
- Modify: `Sources/IleDelbe/Views/NotchViewModel.swift`, `Sources/IleDelbe/Views/NotchRootView.swift`, `Sources/IleDelbe/App/NotchWindowController.swift`, `Sources/IleDelbe/App/AppDelegate.swift`, `Readme.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `NotchViewModel` gains `timer: TimerService`, `history: HistoryService`, `halo: HaloService`, `calendar: CalendarService`, `files: RecentFilesService`, `selectedTab: PanelTab`, `lastUsedTab: PanelTab` (persisted key "panel.lastTab"), `isDraggingFile: Bool`, computed `closedLayout: ClosedLayout` (via `PanelRules.closedLayout`), and `func panelWillOpen(fromBubble: Bool)` which sets `selectedTab = fromBubble ? .timer : PanelRules.defaultTab(...)` and clears `timer.ringingUnseen` when the timer tab is shown.

- [ ] **Step 1:** `AppDelegate` creates all services and passes them to the model.
- [ ] **Step 2:** `NotchRootView`: open → `TabBarView` + selected pane inside the black shape (padding top = notch height + 6), open shape size = `geometry.expanded.size`; closed → `ClosedActivityView(layout:)`; `.mediaAndBubble` → `BubbleView` placed at `geometry.bubble` (relative to window origin) with spring insert/remove transition (scale from 0.6 + offset −30 x + opacity), hidden while open. Halo shadows applied from `halo.glow`. Hovering or clicking the `.alert` notch acknowledges via `timer.acknowledge()` when the panel opens.
- [ ] **Step 3:** `NotchWindowController`:
  - Closed trigger = `notch`, `closedActive` (layouts `.media`, `.mediaAndBubble`, `.timer`, `.alert`) **plus** `bubble` when layout is `.mediaAndBubble`.
  - Remember whether the open was triggered from the bubble rect → `model.panelWillOpen(fromBubble:)` just before `isOpen` becomes true.
  - While `model.isDraggingFile`, `inTrigger = true`. Add global + local `.leftMouseUp` monitors that clear `isDraggingFile` and call `evaluateHover()`.
  - Re-evaluate hover when `closedLayout` changes (observation), so the trigger rect follows the bubble.
  - Closed `ignoresMouseEvents` stays `true` (bubble included).
- [ ] **Step 4:** Readme: v2 features, Calendar permission, Spotlight/file-access prompts, note that ad-hoc signed dev builds may re-ask permissions after each rebuild.
- [ ] **Step 5:** `swift build` warning-free, `make test` green, `make run`.
- [ ] **Step 6: Verification checklist** (record PASS / FAIL / NEEDS HUMAN with evidence in the commit body; never use synthesized clicks outside the panel; pause Spotify and quit the app at the end):
  1. Spotify playing, closed → media wings + glow in artwork color; artwork without color → no glow.
  2. Start a 5 min timer from Minuteur, close panel → bubble appears right of the notch with ring + mm:ss; pause Spotify → bubble retracts, timer in wings; resume → bubble back.
  3. Hover the bubble → panel opens on Minuteur.
  4. Timer reaches 0 (use a 5 s debug duration temporarily if needed) → "Glass" sound, orange alert; hovering opens on Minuteur with "Minuteur terminé" + "OK"; untouched alert clears after 60 s.
  5. Quit and relaunch with a running timer → restored; with an expired one → idle, no alert.
  6. Agenda: first open prompts for Calendar; granted → next 2 events, "Rejoindre" on a Meet/Zoom/Teams event; denied → message + "Ouvrir les Réglages". Info line visible when an event starts within 60 min.
  7. Fichiers: 3 most recent files with real icons; click opens; drag a file into Finder/Mail → panel stays open during the drag, closes after.
  8. Default tab rules on open; last used tab remembered when nothing plays.
  9. Idle CPU (nothing playing, no timer, panel closed) ≈ 0.0 %; with a running timer and panel closed < 1 %.
  10. v1 anti-goals still hold: typing focus, menu bar clicks, full screen (NEEDS HUMAN if not automatable).
- [ ] **Step 7:** Commit `feat: v2 stack hub integration`.
