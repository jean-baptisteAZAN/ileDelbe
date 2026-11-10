# ileDelbe 0.3 — modules, styles et réglages : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the panel into modules shown at three sizes, add the Île and Grille styles next to the existing Onglets style, and add a Réglages window whose settings apply live.

**Architecture:** All rules stay pure and tested in `IleDelbeCore`: settings with validation, panel sizing per style, geometry with asymmetric wings, page navigation, and a swipe accumulator. `IleDelbe` gains a settings store, one dispatcher view per module and size, one view per style, and a settings window. The window controller stops using a constant panel size. It asks the model for the current shape size, so a future style (Rail, 0.4) never touches it.

**Tech Stack:** Swift 6.3, Swift 6 language mode, SwiftPM, SwiftUI + AppKit, Swift Testing, ServiceManagement (`SMAppService`).

**Spec:** `docs/superpowers/specs/2026-11-10-styles-and-settings-0.3-design.md` (read its « Précisions » section: it pins every size and edge case).

## Global Constraints

- macOS 15.4+, Swift 6 language mode, no new dependencies except Apple frameworks.
- The open-panel size is never a constant in the controller or the root view. It always comes from `PanelSizing`.
- Never steal focus. There are three exceptions: the Réglages window, « Rejoindre », and opening a file.
- Clicks and hover follow the shape actually drawn. The transparent window margin never takes clicks (keep `updateMousePassThrough` semantics).
- Idle CPU ~0 %. No polling. The marquee and equalizer run at 15 fps max, only while visible and playing.
- `UserDefaults` key for settings: `settings.v1`. The 0.2 keys `panel.lastTab`, `timer.v1` and `history.v1` are unchanged.
- UI copy in French, exactly as the spec writes it: « Réglages ileDelbe », « Réglages… », « Tout voir », « Aucun module affiché », « Quitter ».
- Version 0.3.0 (`Info.plist` `CFBundleShortVersionString` 0.3.0, `CFBundleVersion` 3, `IleDelbeCore.version`).
- Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Settings changed while the panel is open** (style, density, a module hidden): the shape, the hover rect and the window frame must follow at once. The panel must not stay open with a stale hit rect or close on its own. Test: Task 5 `windowFrameCoversEveryStateOfStyle`; manual check in Task 9.
2. **Hiding the module currently shown**: the page or tab falls back to the first visible module without crashing. Test: Task 2 `defaultTabFallsBackWhenLastUsedHidden`; Task 4 `stepFromHiddenPageGoesToFirst`.
3. **Trackpad momentum after a swipe** must not skip pages. A vertical scroll must not change page. Test: Task 4 `momentumIgnored`, `verticalScrollIgnored`.
4. **Zero visible modules**: every style shows the 300 pt empty panel with the gear, and the closed notch stays plain. Test: Task 2 `emptySize`; Task 3 `closedLayoutHiddenModules`.
5. **Corrupt or old settings data** (garbage, unknown enum value, out-of-range numbers) must never crash and must keep the valid fields. Test: Task 1 `partialAndInvalidFieldsKeepValidOnes`.

---

### Task 1: `AppSettings` (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Settings/AppSettings.swift`
- Test: `Tests/IleDelbeCoreTests/AppSettingsTests.swift`

**Interfaces:**
- Produces:
  - `public enum PanelStyle: String, Codable, CaseIterable, Sendable { case island, grid, tabs }`
  - `public enum AccentSource: String, Codable, CaseIterable, Sendable { case artwork, fixed, none }`
  - `public enum FixedTint: String, Codable, CaseIterable, Sendable { case blue, green, violet, yellow, white; public var hex: String }`, with hex values `#5B8CFF`, `#3ECF8E`, `#C06BFF`, `#F5C542`, `#FFFFFF`
  - `public enum ClosedStyle: String, Codable, CaseIterable, Sendable { case artworkEqualizer, title, none }`
  - `public enum PanelDensity: String, Codable, CaseIterable, Sendable { case normal, compact }`
  - `public struct ModuleEntry: Codable, Equatable, Sendable { public var module: PanelTab; public var visible: Bool }`
  - `public struct AppSettings: Codable, Equatable, Sendable`, with these fields and defaults:
    - `style = .island`
    - `accent = .artwork`, `fixedTint = .blue`
    - `haloIntensity = 0.6` (0…1)
    - `modules` = the four modules, all visible, in the order music, timer, agenda, files
    - `forcedModule: PanelTab? = nil`
    - `closedStyle = .artworkEqualizer`
    - `animateClosed = true`
    - `openDelay = 0.15`
    - `timerPresetsMinutes = [5, 10, 25]`
    - `density = .normal`
    - `recentFileCount = 3`
  - `public static let `default``, `public static let storageKey = "settings.v1"`
  - `public static func load(_ data: Data?) -> AppSettings`, `public func encoded() -> Data`
  - `public func normalized() -> AppSettings`
  - `public var visibleModules: [PanelTab]`
  - `public mutating func setVisible(_ module: PanelTab, _ visible: Bool)`
  - `public mutating func moveModule(from: Int, to: Int)`

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct AppSettingsTests {
    @Test func defaults() {
        let s = AppSettings.default
        #expect(s.style == .island && s.accent == .artwork && s.haloIntensity == 0.6)
        #expect(s.visibleModules == [.music, .timer, .agenda, .files])
        #expect(s.openDelay == 0.15 && s.timerPresetsMinutes == [5, 10, 25] && s.recentFileCount == 3)
        #expect(s.closedStyle == .artworkEqualizer && s.density == .normal && s.forcedModule == nil)
        #expect(s.animateClosed)
    }
    @Test func roundTrip() {
        var s = AppSettings.default; s.style = .grid; s.fixedTint = .violet; s.accent = .fixed
        #expect(AppSettings.load(s.encoded()) == s)
    }
    @Test func garbageAndNilGiveDefault() {
        #expect(AppSettings.load(nil) == .default)
        #expect(AppSettings.load(Data("not json".utf8)) == .default)
    }
    @Test func partialAndInvalidFieldsKeepValidOnes() {
        let json = #"{"style":"rail","closedStyle":"title","openDelay":5,"haloIntensity":-1,"recentFileCount":4}"#
        let s = AppSettings.load(Data(json.utf8))
        #expect(s.style == .island)          // unknown value → default
        #expect(s.closedStyle == .title)     // valid field kept
        #expect(s.openDelay == 0.6 && s.haloIntensity == 0 && s.recentFileCount == 3)
    }
    @Test func delaySnapsToStep() {
        var s = AppSettings.default; s.openDelay = 0.17
        #expect(s.normalized().openDelay == 0.15)
        s.openDelay = 0.01
        #expect(s.normalized().openDelay == 0.05)
    }
    @Test func presetsClampedAndPadded() {
        var s = AppSettings.default; s.timerPresetsMinutes = [0, 500, 10, 4]
        #expect(s.normalized().timerPresetsMinutes == [1, 180, 10])
        s.timerPresetsMinutes = [7]
        #expect(s.normalized().timerPresetsMinutes == [7, 10, 25])
    }
    @Test func modulesRepaired() {
        var s = AppSettings.default
        s.modules = [ModuleEntry(module: .files, visible: false), ModuleEntry(module: .files, visible: true),
                     ModuleEntry(module: .music, visible: true)]
        #expect(s.normalized().modules.map(\.module) == [.files, .music, .timer, .agenda])
        #expect(s.normalized().modules.map(\.visible) == [false, true, true, true])
    }
    @Test func forcedModuleClearedWhenHidden() {
        var s = AppSettings.default; s.forcedModule = .timer
        s.setVisible(.timer, false)
        #expect(s.forcedModule == nil && !s.visibleModules.contains(.timer))
    }
    @Test func moveModule() {
        var s = AppSettings.default; s.moveModule(from: 3, to: 0)
        #expect(s.modules.map(\.module) == [.files, .music, .timer, .agenda])
    }
}
```

- [ ] **Step 2: Run** `swift test --filter AppSettingsTests`. Expected: FAIL (types not defined).
- [ ] **Step 3: Implement.**
  - A custom `init(from:)` decodes each field with `(try? c.decodeIfPresent(T.self, forKey: k)) ?? default`, so one bad field never discards the rest. It then applies `normalized()`.
  - `load` returns `.default` when the data is nil or the top level fails to decode.
  - `normalized()` does the following:
    - clamps `haloIntensity` to 0…1;
    - clamps `openDelay` to 0.05…0.6 and snaps it to 0.05 steps (round to nearest);
    - for each preset, rounds and clamps to 1…180, keeps the first 3, and pads missing ones with the defaults at the same index;
    - sets `recentFileCount` to 3 unless it is 3 or 5;
    - for modules, keeps each module's first occurrence and appends missing ones (visible) in default order;
    - sets `forcedModule` to nil if that module is not visible.
- [ ] **Step 4: Run** `swift test --filter AppSettingsTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(core): AppSettings with per-field fallback and validation`.

### Task 2: `PanelSizing` and module rules (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Panel/PanelSizing.swift`
- Modify: `Sources/IleDelbeCore/Panel/PanelRules.swift` (`defaultTab` gains parameters; add `effectiveModules`)
- Test: `Tests/IleDelbeCoreTests/PanelSizingTests.swift`, `Tests/IleDelbeCoreTests/PanelRulesTests.swift`

**Interfaces:**
- Consumes: `PanelStyle`, `PanelDensity`, `ModuleEntry` (Task 1).
- Produces:
  - `public enum PanelSizing`:
    - `public static func size(style: PanelStyle, showsAll: Bool, modules: [PanelTab], density: PanelDensity, notchHeight h: CGFloat) -> CGSize`
    - `public static func maxSize(style: PanelStyle, modules: [PanelTab], density: PanelDensity, notchHeight: CGFloat) -> CGSize`: for `.island`, the component-wise max of the island and grid sizes (« Tout voir »); for other styles, the style's own size.
    - `public static let compactScale: CGFloat = 0.88`
  - `PanelRules.defaultTab(timerRingingUnseen: Bool, isPlaying: Bool, lastUsed: PanelTab, forced: PanelTab?, available: [PanelTab]) -> PanelTab?`. The old 3-argument version is removed, and callers are updated in Task 5.
  - `PanelRules.effectiveModules(_ entries: [ModuleEntry], timerRinging: Bool) -> [PanelTab]`: the visible modules in order. When `timerRinging` is true and the timer is hidden, the timer is inserted at its position in `entries`.

Sizes, in normal density, with `h` the notch height. `modules` is the list passed in (already effective).

| Case | Size |
|---|---|
| `modules` empty, any style | 300 × (h + 80) |
| `.tabs` | 548 × 236 (absolute) |
| `.island`, `showsAll == false` | 460 × (h + 96) |
| `.grid`, or `.island` with `showsAll`, music present with others | 640 × (h + 236) |
| same, music is the only module | 380 × (h + 236) |
| same, no music, `n = ceil(count / 2)` rows | 520 × (h + 32 + n·96 + (n − 1)·10) |

In compact density: `width = (w * 0.88).rounded()` and `height = h + ((H - h) * 0.88).rounded()`, where H is the total height.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct PanelSizingTests {
    let all: [PanelTab] = [.music, .timer, .agenda, .files]
    func size(_ s: PanelStyle, _ m: [PanelTab], all showsAll: Bool = false, _ d: PanelDensity = .normal) -> CGSize {
        PanelSizing.size(style: s, showsAll: showsAll, modules: m, density: d, notchHeight: 32)
    }
    @Test func tabs() { #expect(size(.tabs, all) == CGSize(width: 548, height: 236)) }
    @Test func island() { #expect(size(.island, all) == CGSize(width: 460, height: 128)) }
    @Test func islandShowsAllIsGrid() { #expect(size(.island, all, all: true) == size(.grid, all)) }
    @Test func gridWithMusic() { #expect(size(.grid, all) == CGSize(width: 640, height: 268)) }
    @Test func gridMusicOnly() { #expect(size(.grid, [.music]) == CGSize(width: 380, height: 268)) }
    @Test func gridNoMusic() {
        #expect(size(.grid, [.timer]) == CGSize(width: 520, height: 160))
        #expect(size(.grid, [.timer, .agenda, .files]) == CGSize(width: 520, height: 266))
    }
    @Test func emptySize() {
        for s in PanelStyle.allCases { #expect(size(s, []) == CGSize(width: 300, height: 112)) }
    }
    @Test func compactKeepsNotchBand() {
        #expect(size(.island, all, .compact) == CGSize(width: 405, height: 116))
        #expect(size(.tabs, all, .compact) == CGSize(width: 482, height: 212))
    }
    @Test func maxSizeIslandCoversShowsAll() {
        let m = PanelSizing.maxSize(style: .island, modules: all, density: .normal, notchHeight: 32)
        #expect(m == CGSize(width: 640, height: 268))
    }
}
```

Add to `PanelRulesTests`:

```swift
@Test func defaultTabRules() {
    let all: [PanelTab] = [.music, .timer, .agenda, .files]
    #expect(PanelRules.defaultTab(timerRingingUnseen: true, isPlaying: true, lastUsed: .files, forced: .agenda, available: all) == .timer)
    #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .files, forced: .agenda, available: all) == .agenda)
    #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .agenda, forced: nil, available: all) == .music)
    #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: false, lastUsed: .agenda, forced: nil, available: all) == .agenda)
    #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: false, lastUsed: .agenda, forced: nil, available: []) == nil)
}
@Test func defaultTabFallsBackWhenLastUsedHidden() {
    #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .agenda, forced: nil, available: [.files, .agenda].filter { $0 != .agenda }) == .files)
}
@Test func effectiveModulesAddsRingingHiddenTimer() {
    let entries = [ModuleEntry(module: .music, visible: true), ModuleEntry(module: .timer, visible: false),
                   ModuleEntry(module: .agenda, visible: true), ModuleEntry(module: .files, visible: false)]
    #expect(PanelRules.effectiveModules(entries, timerRinging: false) == [.music, .agenda])
    #expect(PanelRules.effectiveModules(entries, timerRinging: true) == [.music, .timer, .agenda])
}
```

Delete the old `defaultTab()` test.

- [ ] **Step 2: Run** `swift test --filter "PanelSizingTests|PanelRulesTests"`. Expected: FAIL.
- [ ] **Step 3: Implement** `PanelSizing` (constants exactly as in the table) and the two rules. `defaultTab` applies, in order: ringing (when the timer is in `available`), then forced, then music while playing, then last used, then the first available, else nil.
- [ ] **Step 4: Run** the same filter. Expected: PASS. `swift build` fails at the old `defaultTab` call site in `NotchViewModel`. Pass `forced: nil, available: PanelTab.allCases` there for now and add `?? .music`. Task 5 replaces it.
- [ ] **Step 5: Commit** `feat(core): panel sizing per style and module-aware default tab`.

### Task 3: Geometry with asymmetric wings and closed layout with hidden modules (Core)

**Files:**
- Modify: `Sources/IleDelbeCore/Notch/NotchGeometry.swift`, `Sources/IleDelbeCore/Panel/PanelRules.swift`
- Test: `Tests/IleDelbeCoreTests/NotchGeometryTests.swift`, `Tests/IleDelbeCoreTests/PanelRulesTests.swift`

**Interfaces:**
- Produces:
  - `NotchGeometry` becomes `{ notch: CGRect; screenMaxY: CGFloat }`, and `make(...)` keeps its signature. Remove `closedActive`, `closedAlert`, `expanded`, `bubble` and `expandedSize`. Add:
    - `public func closedRect(_ wings: ClosedWings) -> CGRect`
    - `public func openRect(size: CGSize) -> CGRect`: centered on `notch.midX`, top at `screenMaxY`
    - `public func bubbleRect(after closed: CGRect) -> CGRect`: x = `closed.maxX + bubbleGap`, width `bubbleWidth`, notch height
  - Keep the constants `bubbleWidth = 76` and `bubbleGap = 8`.
  - `public struct ClosedWings: Equatable, Sendable { public var left: CGFloat; public var right: CGFloat }` with `static let none`, `standard (36, 36)`, `title (36, 120)`, `alert (110, 110)`.
  - `PanelRules.closedLayout(isPlaying: Bool, timerActive: Bool, timerRinging: Bool, showsMusic: Bool, showsTimer: Bool) -> ClosedLayout`. The caller passes `showsMusic` as music visible and `closedStyle != .none`, and `showsTimer` as timer visible. Ringing gives `.alert` always. Music is counted only when `isPlaying && showsMusic`, and the timer only when `timerActive && showsTimer`. Then the 0.2 combination rules apply.
  - `PanelRules.closedWings(_ layout: ClosedLayout, closedStyle: ClosedStyle) -> ClosedWings`:
    - `.plain` → `.none`;
    - `.media` and `.mediaAndBubble` → `.title` when `closedStyle == .title`, else `.standard`;
    - `.timer` → `.standard`;
    - `.alert` → `.alert`.

- [ ] **Step 1: Write the failing tests.** Replace the rect tests in `NotchGeometryTests`, keeping the same `make()` fixture (notch 662, 950, 188 × 32, screen 1512 × 982):

```swift
@Test func closedRects() {
    let g = make()!
    #expect(g.closedRect(.standard) == CGRect(x: 626, y: 950, width: 260, height: 32))
    #expect(g.closedRect(.alert) == CGRect(x: 552, y: 950, width: 408, height: 32))
    #expect(g.closedRect(.title) == CGRect(x: 626, y: 950, width: 344, height: 32))
    #expect(g.closedRect(.none) == g.notch)
}
@Test func openRect() {
    #expect(make()!.openRect(size: CGSize(width: 548, height: 236)) == CGRect(x: 482, y: 746, width: 548, height: 236))
}
@Test func bubbleFollowsActualWing() {
    let g = make()!
    #expect(g.bubbleRect(after: g.closedRect(.standard)) == CGRect(x: 894, y: 950, width: 76, height: 32))
    #expect(g.bubbleRect(after: g.closedRect(.title)).minX == 978)
}
```

Keep the existing no-notch and origin-offset tests, adapted to the new API. In `PanelRulesTests`, rename the existing `closedLayout()` test and pass `showsMusic: true, showsTimer: true`. Then add:

```swift
@Test func closedLayoutHiddenModules() {
    #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false, showsMusic: false, showsTimer: true) == .timer)
    #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false, showsMusic: true, showsTimer: false) == .media)
    #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: true, showsMusic: false, showsTimer: false) == .alert)
    #expect(PanelRules.closedLayout(isPlaying: true, timerActive: false, timerRinging: false, showsMusic: false, showsTimer: false) == .plain)
}
@Test func closedWings() {
    #expect(PanelRules.closedWings(.media, closedStyle: .title) == .title)
    #expect(PanelRules.closedWings(.mediaAndBubble, closedStyle: .artworkEqualizer) == .standard)
    #expect(PanelRules.closedWings(.alert, closedStyle: .title) == .alert)
    #expect(PanelRules.closedWings(.plain, closedStyle: .title) == .none)
}
```

- [ ] **Step 2: Run** `swift test --filter "NotchGeometryTests|PanelRulesTests"`. Expected: FAIL.
- [ ] **Step 3: Implement.** In the app target, keep the build green with minimal shims: callers of the old rects use `closedRect(.standard)`, `closedRect(.alert)`, `openRect(size: CGSize(width: 548, height: 236))` and `bubbleRect(after: closedRect(.standard))`. Task 5 replaces them.
- [ ] **Step 4: Run** `make test`. Expected: all tests PASS and `swift build` is clean.
- [ ] **Step 5: Commit** `feat(core): asymmetric closed wings, closed layout honours hidden modules`.

### Task 4: Hover delay, forced close, swipe and paging (Core)

**Files:**
- Modify: `Sources/IleDelbeCore/Notch/HoverStateMachine.swift`
- Create: `Sources/IleDelbeCore/Panel/PageSwipe.swift`
- Test: `Tests/IleDelbeCoreTests/HoverStateMachineTests.swift`, `Tests/IleDelbeCoreTests/PageSwipeTests.swift`

**Interfaces:**
- Produces:
  - `HoverStateMachine`:
    - `public init(openDelay: TimeInterval = 0.15)` and `public var openDelay: TimeInterval`. The static `openDelay` is removed; `closeDelay` stays static at 0.30.
    - `public mutating func forceClose()`: closes immediately. While closed, it then ignores `inTrigger == true` until one `update(inTrigger: false, …)` has been seen.
  - `public enum PageStep: Sendable { case next, previous }`
  - `public struct PageSwipe: Sendable`:
    - `public enum Phase: Sendable { case began, changed, ended, none }`
    - `public static let threshold: CGFloat = 24`
    - `public init()`
    - `public mutating func feed(deltaX: CGFloat, deltaY: CGFloat, phase: Phase, isMomentum: Bool) -> PageStep?`
  - `PanelRules.step(from current: PanelTab?, _ step: PageStep, in pages: [PanelTab]) -> PanelTab?`: clamps at both ends with no wrap. A `current` that is not in `pages` gives `pages.first`.

Swipe rules:
- Momentum events are ignored.
- `.began` resets the accumulators and the lock.
- `.changed` adds to `accX` and `accY`, unless locked. The first time `|accX| >= threshold && |accX| > |accY|`, it locks and returns `accX < 0 ? .next : .previous`.
- `.ended` resets.
- `.none` (a legacy wheel, one discrete event) returns a step if `|deltaX| >= threshold && |deltaX| > |deltaY|`, and stores nothing.

- [ ] **Step 1: Write the failing tests**

```swift
// HoverStateMachineTests additions
@Test func customOpenDelay() {
    var h = HoverStateMachine(openDelay: 0.5)
    h.update(inTrigger: true, now: 0); h.update(inTrigger: true, now: 0.4)
    #expect(!h.isOpen)
    h.update(inTrigger: true, now: 0.5)
    #expect(h.isOpen)
}
@Test func forceCloseNeedsExitBeforeReopen() {
    var h = HoverStateMachine()
    h.update(inTrigger: true, now: 0); h.update(inTrigger: true, now: 0.2)
    h.forceClose()
    #expect(!h.isOpen)
    h.update(inTrigger: true, now: 1); h.update(inTrigger: true, now: 2)
    #expect(!h.isOpen && h.nextDeadline == nil)
    h.update(inTrigger: false, now: 3); h.update(inTrigger: true, now: 4); h.update(inTrigger: true, now: 4.2)
    #expect(h.isOpen)
}

@Suite struct PageSwipeTests {
    @Test func onePagePerGesture() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false) == nil)
        #expect(s.feed(deltaX: -15, deltaY: 1, phase: .changed, isMomentum: false) == nil)
        #expect(s.feed(deltaX: -15, deltaY: 1, phase: .changed, isMomentum: false) == .next)
        #expect(s.feed(deltaX: -80, deltaY: 0, phase: .changed, isMomentum: false) == nil)
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .ended, isMomentum: false)
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false)
        #expect(s.feed(deltaX: 30, deltaY: 0, phase: .changed, isMomentum: false) == .previous)
    }
    @Test func momentumIgnored() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: -100, deltaY: 0, phase: .changed, isMomentum: true) == nil)
    }
    @Test func verticalScrollIgnored() {
        var s = PageSwipe()
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false)
        #expect(s.feed(deltaX: -30, deltaY: -60, phase: .changed, isMomentum: false) == nil)
    }
    @Test func pagingClamps() {
        let p: [PanelTab] = [.music, .timer, .files]
        #expect(PanelRules.step(from: .music, .next, in: p) == .timer)
        #expect(PanelRules.step(from: .files, .next, in: p) == .files)
        #expect(PanelRules.step(from: .music, .previous, in: p) == .music)
        #expect(PanelRules.step(from: nil, .next, in: []) == nil)
    }
    @Test func stepFromHiddenPageGoesToFirst() {
        #expect(PanelRules.step(from: .agenda, .next, in: [.music, .files]) == .music)
    }
}
```

- [ ] **Step 2: Run** `swift test --filter "HoverStateMachineTests|PageSwipeTests"`. Expected: FAIL.
- [ ] **Step 3: Implement.** Update existing hover tests that use the old static `HoverStateMachine.openDelay` so they use the instance value.
- [ ] **Step 4: Run** `make test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(core): configurable open delay, forced close, one-page swipe`.

### Task 5: Settings store, model and dynamic geometry in the app

**Files:**
- Create: `Sources/IleDelbe/Services/SettingsStore.swift`
- Modify:
  - `Sources/IleDelbe/Views/NotchViewModel.swift`
  - `Sources/IleDelbe/App/NotchWindowController.swift`
  - `Sources/IleDelbe/Views/NotchRootView.swift`
  - `Sources/IleDelbe/App/AppDelegate.swift`
  - `Sources/IleDelbe/Views/TimerPaneView.swift` (presets from settings)
  - `Sources/IleDelbe/Views/FilesPaneView.swift` (count)
  - `Sources/IleDelbeCore/Files/RecentFile.swift` (`limit = 5`; views slice to the setting)
- Test: `Tests/IleDelbeCoreTests/PanelSizingTests.swift` (add `windowFrameCoversEveryStateOfStyle`)

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `@MainActor @Observable final class SettingsStore`:
    - `var settings: AppSettings`: `didSet` normalizes and persists under `AppSettings.storageKey`.
    - `init(defaults: UserDefaults = .standard)`
  - `NotchViewModel` gains:
    - `let settings: SettingsStore`
    - `var modules: [PanelTab]`: `PanelRules.effectiveModules(settings.modules, timerRinging: timer.timer.isRinging)`
    - `private(set) var selectedTab: PanelTab?`, now optional (nil = no module)
    - `var showsAll = false`: Île « Tout voir »; reset to false in `panelDidClose()`
    - `var panelSize: CGSize`: `PanelSizing.size` with the current style, `showsAll` and `modules`, using `geometry?.notch.height ?? 32`
    - `var closedWings: ClosedWings`
    - `var accent: Color?`: artwork → `halo.glow`; fixed → the tint color; none → nil
    - `var haloOpacityScale: Double`: `settings.haloIntensity / 0.6`, capped so that today's 0.2 look stays at the default
    - `func step(_ step: PageStep)`
    - `func openSettings()` (calls an `onOpenSettings` closure set by the AppDelegate)
  - `closedLayout` passes `showsMusic` and `showsTimer` from the visible modules and `closedStyle`.
  - `panelWillOpen` uses the new `defaultTab` with `forced: settings.forcedModule` and `available: modules`.
  - `NotchWindowController`:
    - `hover.openDelay` follows `settings.openDelay`;
    - the window frame is `geometry.openRect(size: PanelSizing.maxSize(...))` plus the halo margin, recomputed whenever the style, density or modules change (observation re-arm, like `observeClosedLayout`);
    - open trigger = `geometry.openRect(size: model.panelSize)`;
    - closed trigger = `closedRect(model.closedWings)`, plus `bubbleRect(after:)` when `.mediaAndBubble`;
    - `func closeNow()` calls `hover.forceClose()` and then applies.
  - `NotchRootView` sizes the shape from `model.panelSize` (open) or `closedRect(model.closedWings).size` (closed). The halo uses `model.accent` and `haloOpacityScale`. The open content still renders the 0.2 tab bar and panes (the Onglets style). It shows only `model.modules`, in order, with the gear slot left for Task 8.

- [ ] **Step 1: Write the failing test** (pure; in `PanelSizingTests`):

```swift
@Test func windowFrameCoversEveryStateOfStyle() {
    let subsets: [[PanelTab]] = [[], [.music], [.timer], [.music, .timer, .agenda, .files], [.timer, .agenda, .files]]
    for style in PanelStyle.allCases {
        for d in PanelDensity.allCases {
            for m in subsets {
                let max = PanelSizing.maxSize(style: style, modules: m, density: d, notchHeight: 32)
                for showsAll in [false, true] {
                    let s = PanelSizing.size(style: style, showsAll: showsAll && style == .island, modules: m, density: d, notchHeight: 32)
                    #expect(s.width <= max.width && s.height <= max.height)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run** `swift test --filter PanelSizingTests`. Expected: PASS if Task 2 is right, otherwise fix `maxSize`. This test guards the window frame.
- [ ] **Step 3: Implement the store, the model changes and the controller and root view changes listed above.** Remove every remaining use of a constant panel size, and grep for `548` and `expanded` to confirm. Pass the accent to `ScrubberView.fill` and `EqualizerView.color` (white when nil). Pass `settings.timerPresetsMinutes` to `TimerPaneView` (replacing `CountdownTimer.presets`) and `settings.recentFileCount` to `FilesPaneView`.
- [ ] **Step 4: Verify.** Run `make test` (all PASS) and `make app && make run`. Check that the app looks and behaves exactly like 0.2 when `style` is set to `.tabs`: `defaults write io.github.ileDelbe settings.v1 -data $(printf '{"style":"tabs"}' | xxd -p)`. Check that the default Île style falls back to tabs rendering for now but uses the Île size. That is expected until Task 7.
- [ ] **Step 5: Commit** `feat: settings store, dynamic panel geometry, module-aware model`.

### Task 6: Module views at three sizes

**Files:**
- Create:
  - `Sources/IleDelbe/Views/Modules/ModuleSize.swift`: `enum ModuleSize { case compact, card, full }`
  - `Sources/IleDelbe/Views/Modules/ModuleView.swift`: the dispatcher
  - `Sources/IleDelbe/Views/Modules/MusicCompactView.swift`, `MusicCardView.swift`
  - `Sources/IleDelbe/Views/Modules/TimerCompactView.swift`, `TimerCardView.swift`
  - `Sources/IleDelbe/Views/Modules/AgendaCompactView.swift`, `AgendaCardView.swift`
  - `Sources/IleDelbe/Views/Modules/FilesCompactView.swift`, `FilesCardView.swift`
- Modify: `Sources/IleDelbe/Views/NotchRootView.swift`: move `pane(_:)` into `ModuleView(.full)`.

**Interfaces:**
- Consumes: `NotchViewModel` (Task 5) and the existing services and panes.
- Produces: `struct ModuleView: View { let module: PanelTab; let size: ModuleSize; let model: NotchViewModel }`. The `.full` size is the existing pane. Each view takes plain values and closures, like the panes, so `ReadmeAssets` can render it with sample data.

Content per size follows the spec: Île details for `compact`, Grille details for `card`.
- Compact views are about 70 pt high and lay out in a 428 pt-wide row.
- Music compact: artwork 58, title, artist, scrubber and the 3 transport buttons; no volume and no history.
- Music card: everything from the full pane, plus 3 history thumbnails in a row.
- Timer: idle shows the 3 presets from settings; running shows the ring, the time left, « Fin à HH:mm », +1 min, Pause/Reprendre and Arrêter; ringing shows « OK ».
- Agenda: one event with « Rejoindre », plus the 0.2 denied and not-determined states, with `onAppear` asking for access exactly as the pane does.
- Files compact: 3 tiles, with « +N » when `recentFileCount > 3`. Files card: `recentFileCount` icons in a row. Both keep click-to-open and drag-out (reuse the pane's drag code, and call `onDragStart`).

- [ ] **Step 1: Build each view with `#Preview` blocks** using the preview samples already in the panes (states: playing, idle timer, running timer, ringing, agenda granted, agenda denied, 5 files).
- [ ] **Step 2: Verify** with `swift build` (clean, no warnings in new files) and `make test` (PASS).
- [ ] **Step 3: Commit** `feat: module views at compact, card and full sizes`.

### Task 7: Île and Grille styles, the gear, swipe

**Files:**
- Create:
  - `Sources/IleDelbe/Views/Styles/PanelContentView.swift`: switches on style and `showsAll`
  - `Sources/IleDelbe/Views/Styles/IslandStyleView.swift`
  - `Sources/IleDelbe/Views/Styles/GridStyleView.swift`
  - `Sources/IleDelbe/Views/Styles/TabsStyleView.swift`: the 0.2 bar and pane, moved out of `NotchRootView`
  - `Sources/IleDelbe/Views/Styles/SettingsButton.swift`
  - `Sources/IleDelbe/Views/Styles/EmptyPanelView.swift`: « Aucun module affiché » and the gear
- Modify:
  - `Sources/IleDelbe/Views/NotchRootView.swift`: the open content becomes `PanelContentView`; compact density scales the content below the notch band with `.scaleEffect(PanelSizing.compactScale, anchor: .top)`
  - `Sources/IleDelbe/App/NotchWindowController.swift`: local scroll monitor
  - `Sources/IleDelbe/Views/TabBarView.swift`: tabs from `model.modules`, plus the gear on the right

**Interfaces:**
- Consumes: `ModuleView` (Task 6), `model.step(_:)`, `model.showsAll`, `model.openSettings()`.
- Produces: none for later tasks besides `SettingsButton(action:)`.

Behaviour:
- **Île:**
  - One `ModuleView(size: .compact)` page for `model.selectedTab`, with a horizontal spring slide between pages (`.transition(.push(from: .trailing/.leading))` keyed by direction).
  - Below it, the dots, one per module. They are hidden when there is a single module. Click → select.
  - To the right of the dots: the « Tout voir » grid button (toggles `model.showsAll`, so the panel becomes `GridStyleView`) and the gear.
- **Grille:** music card on the left and the other cards stacked on the right, or a 2-column layout without music. Gear in the bottom-right corner.
- **Scroll:** `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` in the controller acts only when the panel is open, the style is `.island`, `showsAll` is false and `event.window === panel`. It feeds `PageSwipe` with these mappings:
  - `scrollingDeltaX` and `scrollingDeltaY`;
  - `phase` `.began` → `.began`, `.changed` → `.changed`, `.ended` or `.cancelled` → `.ended`, empty → `.none`;
  - `isMomentum = !event.momentumPhase.isEmpty`.

  A returned step calls `model.step(_:)`, which updates `selectedTab` and `lastUsedTab`. The monitor returns the event unchanged.
- **Gear:** `model.openSettings()` is wired by the AppDelegate to `controller.closeNow()` followed by showing the settings window (Task 9; until then, close only).

- [ ] **Step 1: Implement**, with `#Preview` blocks for Île (each page, one module, ringing) and Grille (all, music only, no music, empty).
- [ ] **Step 2: Verify.**
  - `make test` passes.
  - `make app && make run`:
    - hover opens Île at 460 pt;
    - a two-finger swipe moves exactly one page per gesture, even with a strong flick;
    - a vertical scroll does nothing;
    - « Tout voir » grows to the Grille, and closing and reopening comes back to the pages;
    - clicks just outside the panel reach the menu bar.
- [ ] **Step 3: Commit** `feat: Île and Grille styles with one-page swipe and Tout voir`.

### Task 8: Closed notch styles

**Files:**
- Create: `Sources/IleDelbe/Views/MarqueeText.swift`
- Modify:
  - `Sources/IleDelbe/Views/ClosedActivityView.swift`: wings from `ClosedWings`, title mode, accent-colored equalizer
  - `Sources/IleDelbe/Views/NotchRootView.swift`: bubble offset from `geometry.bubbleRect(after:)`; closed halo only for `.media` and `.mediaAndBubble` with a non-nil accent

**Interfaces:**
- Consumes: `model.closedWings`, `settings.closedStyle`, `model.accent`.
- Produces: `NotchViewModel.closedMotion: Bool`, which is `settings.animateClosed && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. It is re-evaluated on `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`. It drives `EqualizerView` (static bars when false: `TimelineView` paused, constant heights), `MarqueeText.isActive` and the alert pulse (`AlertPulse` static when false).
- Produces: `struct MarqueeText: View { var text: String; var isActive: Bool }`. It scrolls only if the text overflows its width and `isActive`, using `TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !(isActive && overflows)))`. It waits 1.5 s at each end.

- [ ] **Step 1: Implement.** The title mode shows « titre · artiste » in the 120 pt right wing. `.none` leaves the plain notch while playing, with the timer in the wings when active (spec).
- [ ] **Step 2: Verify.** `make test` passes. With `make run`, turn `animateClosed` off: the equalizer is frozen, the title does not scroll, and the alert does not pulse. Do the same with System Settings › Accessibility › Display › Reduce motion. Then switch `closedStyle` through `defaults write`: the bubble sits to the right of the wide wing in title mode, the alert replaces the title while ringing, and Activity Monitor shows ~0 % CPU when paused.
- [ ] **Step 3: Commit** `feat: closed notch title and none styles, accent equalizer`.

### Task 9: Réglages window and launch at login

**Files:**
- Create:
  - `Sources/IleDelbe/App/SettingsWindowController.swift`
  - `Sources/IleDelbe/Views/Settings/SettingsView.swift`
  - `Sources/IleDelbe/Services/LoginItemService.swift`
- Modify:
  - `Sources/IleDelbe/App/AppDelegate.swift`: wire `model.onOpenSettings`
  - `Sources/IleDelbe/Views/NotchRootView.swift`: context menu gains « Réglages… » above « Quitter »

**Interfaces:**
- Consumes: `SettingsStore`, `NotchWindowController.closeNow()`.
- Produces:
  - `@MainActor final class SettingsWindowController { func show() }`:
    - Before showing, it remembers `NSWorkspace.shared.frontmostApplication` (unless it is ileDelbe itself).
    - It then calls `NSApp.activate()` and `makeKeyAndOrderFront`.
    - On `windowWillClose`, it re-activates the remembered app.
    - The window is titled « Réglages ileDelbe », is not resizable, and is reused across opens.
  - `@MainActor @Observable final class LoginItemService`:
    - `var isEnabled: Bool`, read from `SMAppService.mainApp.status == .enabled`
    - `var needsApproval: Bool`, for `.requiresApproval`
    - `func set(_ on: Bool)`, which calls register or unregister and logs errors, then re-reads the status

`SettingsView` holds every row of the spec's table, in that order, bound to `store.settings`:
- Style: segmented control.
- Couleur: segmented control, plus 5 tint swatches shown when « Fixe » is selected.
- Intensité du halo: slider 0…100 %.
- Modules: a list with a toggle per row and up/down buttons (or `onMove`).
- À l'ouverture: a picker with « Automatique » plus the visible modules.
- Encoche fermée: segmented control.
- Animer l'encoche fermée: a toggle.
- Délai d'ouverture: slider 0.05…0.6, step 0.05, value shown as « 0,15 s ».
- Durées du minuteur: three steppers or fields, 1…180.
- Taille du panneau: segmented control.
- Fichiers récents: segmented control, 3 or 5.
- Lancer à l'ouverture de session: a toggle. When approval is needed, show the line « À approuver dans Réglages Système › Général › Ouverture ».

- [ ] **Step 1: Implement**, with a `#Preview` of `SettingsView` using an in-memory `UserDefaults(suiteName:)`.
- [ ] **Step 2: Verify.**
  - `make test` passes.
  - With `make run`:
    - the gear closes the panel and opens the window, with focus;
    - closing the window gives focus back to the previous app;
    - every control applies live on the next hover;
    - hiding the module currently shown while the panel is open falls back cleanly;
    - the context menu « Réglages… » works.
- [ ] **Step 3: Commit** `feat: Réglages window, context menu entry, launch at login`.

### Task 10: README images, docs, version 0.3.0

**Files:**
- Modify:
  - `Sources/IleDelbe/App/ReadmeAssets.swift`
  - `Readme.md`
  - `CHANGELOG.md`
  - `Resources/Info.plist`
  - `Sources/IleDelbeCore/IleDelbeCore.swift` (or wherever `version` lives)
  - `docs/assets/*.png`
- Test: `Tests/IleDelbeCoreTests/SmokeTests.swift` (version string)

- [ ] **Step 1: Update the version test** to `#expect(IleDelbeCore.version == "0.3.0")`. Run it and see it FAIL, then bump `IleDelbeCore.version`, `CFBundleShortVersionString` 0.3.0 and `CFBundleVersion` 3, and see it PASS.
- [ ] **Step 2: Extend `ReadmeAssets`** to render `style-island.png`, `style-grid.png`, `style-tabs.png` and `settings.png` (the `SettingsView` with defaults), plus the existing closed images. Keep the existing hero. Run `make readme-assets` and open the PNGs to check them.
- [ ] **Step 3: Update the docs.**
  - README: a « Styles » section with the three images, one sentence each, and a « Réglages » section listing the settings and how to open the window. Replace the old open-tab images that no longer match the default.
  - CHANGELOG: `## [0.3.0]`, saying that Île is the new default, that the 0.2 look is the Onglets style, and listing the settings; plus a compare link.
- [ ] **Step 4: Verify.** `make test` passes, `make app` builds, and the README renders on GitHub preview (`gh markdown-preview` if available, else check the image paths by hand).
- [ ] **Step 5: Commit** `docs: 0.3.0 README styles and settings, changelog, version bump`.
