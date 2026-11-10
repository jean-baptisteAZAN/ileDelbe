# ileDelbe 0.4 — écrans externes : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the notch on external screens with a virtual notch, a thin idle bar that grows into a pill during activity. The user chooses where the notch appears: built-in screen, main screen, one chosen screen, or all screens.

**Architecture:**
- Two new pure Core pieces, both tested:
  - `ScreenSelection` decides which screens get a notch;
  - `NotchGeometry.virtual(...)` gives a centred 180 pt virtual notch that the existing geometry, sizing and window-frame code reuses unchanged.
- In the app, a `ScreenCoordinator` owns one `NotchWindowController` per selected screen and rebuilds the set on screen or settings changes.
- The shared `NotchViewModel` keeps services, settings and the open module. A single `openScreenID` replaces `isOpen`. Geometry and panel sizes become per screen.

**Tech Stack:** Swift 6.3, Swift 6 language mode, SwiftPM, SwiftUI + AppKit, CoreGraphics display APIs, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-10-external-screens-design.md` (its « Précisions » section is binding).

## Global Constraints

- macOS 15.4+, no new dependencies.
- The screen identity is the CoreGraphics display UUID string (`CGDisplayCreateUUIDFromDisplayID`). The name is only for display.
- Built-in detection uses `CGDisplayIsBuiltin`. Remove the `localizedName.contains("Built-in")` check.
- Default `screenMode = .builtIn`. With no built-in screen, fall back to the main screen, then the first screen. There is always at least one notch while at least one screen exists.
- At most one panel is open at a time (`openScreenID`). Closed activity (wings, bubble, alert) shows on every notch.
- Never steal focus. Clicks and hover follow the drawn shape. At rest on a virtual screen, only the thin bar (with its small trigger tolerance) reacts.
- Idle CPU ~0 % with any number of screens. No polling: screen changes come from `NSApplication.didChangeScreenParametersNotification`.
- Settings live in `settings.v1` with per-field fallback. Missing new fields give `.builtIn` / `nil`.
- French UI copy: « Écrans », « Écran intégré », « Écran principal », « Un écran au choix », « Tous les écrans ».
- Version 0.4.0 (`Info.plist` 0.4.0 / build 4, `IleDelbeCore.version`, cask version).
- Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A screen unplugged while its panel is open**: `openScreenID` must be cleared and no window left behind. Test: Task 3, manual hot-plug check.
2. **Chosen screen unplugged, then replugged**: the notch falls back, then returns to the chosen screen. Test: Task 1 `chosenFallsBackAndReturns`.
3. **Pointer crossing quickly from one screen's notch to another's**: never two panels open at once. Test: Task 3, manual check.
4. **Idle bar accidental opens**: the trigger is only the bar plus 6 pt below it, not the menu-bar centre. Test: Task 2 `idleTrigger`.
5. **Laptop lid closed (no built-in screen) in default mode**: the notch moves to the main external screen. Test: Task 1 `builtInMissingUsesMain`.

---

### Task 1: Screen selection and settings (Core)

**Files:**
- Create: `Sources/IleDelbeCore/Screens/ScreenSelection.swift`
- Modify: `Sources/IleDelbeCore/Settings/AppSettings.swift`
- Test: `Tests/IleDelbeCoreTests/ScreenSelectionTests.swift`, `Tests/IleDelbeCoreTests/AppSettingsTests.swift`

**Interfaces:**
- Produces:
  - `public struct ScreenInfo: Equatable, Sendable { public var id: String; public var name: String; public var isBuiltIn: Bool; public var isMain: Bool; public var hasNotch: Bool }` with a memberwise public init.
  - `public enum ScreenMode: String, Codable, CaseIterable, Sendable { case builtIn, main, chosen, all }`
  - `AppSettings` gains `screenMode: ScreenMode = .builtIn` and `chosenScreenID: String? = nil`, decoded per field like the others.
  - `public enum ScreenSelection { public static func targets(_ screens: [ScreenInfo], mode: ScreenMode, chosenID: String?) -> [String] }` returns screen ids in the order of `screens`.

Rules:
- `.builtIn`: the built-in screen, else the main screen, else the first.
- `.main`: the main screen, else the first.
- `.chosen`: the chosen screen if present, else the `.builtIn` rule.
- `.all`: every screen.
- Empty input gives `[]`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ScreenSelectionTests {
    let mac = ScreenInfo(id: "A", name: "Écran intégré", isBuiltIn: true, isMain: false, hasNotch: true)
    let dell = ScreenInfo(id: "B", name: "DELL U2723QE", isBuiltIn: false, isMain: true, hasNotch: false)
    let lg = ScreenInfo(id: "C", name: "LG UltraFine", isBuiltIn: false, isMain: false, hasNotch: false)
    @Test func builtInDefault() { #expect(ScreenSelection.targets([mac, dell, lg], mode: .builtIn, chosenID: nil) == ["A"]) }
    @Test func builtInMissingUsesMain() { #expect(ScreenSelection.targets([dell, lg], mode: .builtIn, chosenID: nil) == ["B"]) }
    @Test func mainScreen() { #expect(ScreenSelection.targets([mac, dell, lg], mode: .main, chosenID: nil) == ["B"]) }
    @Test func noMainFlagUsesFirst() {
        var l = lg; l.isMain = false
        #expect(ScreenSelection.targets([l], mode: .main, chosenID: nil) == ["C"])
    }
    @Test func chosenFallsBackAndReturns() {
        #expect(ScreenSelection.targets([mac, dell, lg], mode: .chosen, chosenID: "C") == ["C"])
        #expect(ScreenSelection.targets([mac, dell], mode: .chosen, chosenID: "C") == ["A"])
        #expect(ScreenSelection.targets([dell], mode: .chosen, chosenID: "C") == ["B"])
        #expect(ScreenSelection.targets([mac, dell, lg], mode: .chosen, chosenID: nil) == ["A"])
    }
    @Test func allScreens() { #expect(ScreenSelection.targets([mac, dell, lg], mode: .all, chosenID: nil) == ["A", "B", "C"]) }
    @Test func empty() { #expect(ScreenSelection.targets([], mode: .all, chosenID: nil).isEmpty) }
}
```

Add to `AppSettingsTests`:

```swift
@Test func screenDefaultsAndFallback() {
    #expect(AppSettings.default.screenMode == .builtIn && AppSettings.default.chosenScreenID == nil)
    let s = AppSettings.load(Data(#"{"screenMode":"mirror","chosenScreenID":"C","style":"grid"}"#.utf8))
    #expect(s.screenMode == .builtIn && s.chosenScreenID == "C" && s.style == .grid)
}
```

- [ ] **Step 2: Run** `swift test --filter "ScreenSelectionTests|AppSettingsTests"`. Expected: FAIL to compile.
- [ ] **Step 3: Implement** the types and rules above.
- [ ] **Step 4: Run** the same filter (PASS), then `make test` (PASS).
- [ ] **Step 5: Commit** `feat(core): screen selection modes and settings`.

### Task 2: Virtual notch geometry (Core)

**Files:**
- Modify: `Sources/IleDelbeCore/Notch/NotchGeometry.swift`
- Test: `Tests/IleDelbeCoreTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  - `NotchGeometry` gains `public let isVirtual: Bool`, which is false for `make(...)`.
  - `public static func virtual(screenFrame: CGRect, menuBarHeight: CGFloat) -> NotchGeometry`: notch is `virtualNotchWidth` (180) wide, centred on `screenFrame.midX`, `menuBarHeight` tall, top at `screenFrame.maxY`; `isVirtual = true`.
  - `public static func menuBarHeight(screenFrame: CGRect, visibleFrame: CGRect, fallback: CGFloat) -> CGFloat`: `screenFrame.maxY - visibleFrame.maxY` when > 0, else `fallback`.
  - Constants: `public static let virtualNotchWidth: CGFloat = 180`, `idleBarSize = CGSize(width: 120, height: 4)`, `idleTolerance: CGFloat = 6`.
  - `public var idleBarRect: CGRect`: centred on `notch.midX`, top at `screenMaxY`, `idleBarSize`.
  - `public func closedShapeRect(_ wings: ClosedWings) -> CGRect`: `idleBarRect` when `isVirtual && wings == .none`, else `closedRect(wings)`.
  - `public func closedTriggerRect(_ wings: ClosedWings) -> CGRect`: when `isVirtual && wings == .none`, `idleBarRect` grown downward by `idleTolerance` (same width, height 4 + 6), else `closedRect(wings)`.
  - `windowFrame(...)` must still cover every closed footprint for virtual geometry, without changes if the existing union already does.

- [ ] **Step 1: Write the failing tests** (external screen right of the laptop, 2560 × 1440 at x = 1512, menu bar 24):

```swift
let ext = NotchGeometry.virtual(screenFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), menuBarHeight: 24)
@Test func virtualNotch() {
    #expect(ext.isVirtual)
    #expect(ext.notch == CGRect(x: 2702, y: 1416, width: 180, height: 24))
}
@Test func idleBar() {
    #expect(ext.idleBarRect == CGRect(x: 2732, y: 1436, width: 120, height: 4))
    #expect(ext.closedShapeRect(.none) == ext.idleBarRect)
    #expect(ext.closedShapeRect(.standard) == ext.closedRect(.standard))
}
@Test func idleTrigger() {
    #expect(ext.closedTriggerRect(.none) == CGRect(x: 2732, y: 1430, width: 120, height: 10))
}
@Test func hardwareNotchUnchanged() {
    let g = make()!
    #expect(!g.isVirtual && g.closedShapeRect(.none) == g.notch && g.closedTriggerRect(.none) == g.notch)
}
@Test func menuBarHeightFallback() {
    #expect(NotchGeometry.menuBarHeight(screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 76), fallback: 24) == 24)
    #expect(NotchGeometry.menuBarHeight(screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100), fallback: 24) == 24)
    #expect(NotchGeometry.menuBarHeight(screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 70), fallback: 24) == 30)
}
@Test func virtualWindowFrameCoversPill() {
    let w = ext.windowFrame(openSize: CGSize(width: 460, height: 120), openMargin: (horizontal: 35, bottom: 48), closedMargin: 11)
    #expect(w.contains(ext.closedRect(.alert)) && w.contains(ext.idleBarRect))
}
```

(Adapt the `windowFrame` call to its real signature.)

- [ ] **Step 2: Run** `swift test --filter NotchGeometryTests`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the filter (PASS), then `make test` (PASS).
- [ ] **Step 5: Commit** `feat(core): virtual notch geometry with idle bar`.

### Task 3: One window per screen, shared model

**Files:**
- Create:
  - `Sources/IleDelbe/App/ScreenCoordinator.swift`
  - `Sources/IleDelbe/App/ScreenProvider.swift`: `NSScreen` → `ScreenInfo` + geometry
- Modify:
  - `Sources/IleDelbe/App/NotchWindowController.swift`
  - `Sources/IleDelbe/Views/NotchViewModel.swift`
  - `Sources/IleDelbe/Views/NotchRootView.swift`
  - `Sources/IleDelbe/App/AppDelegate.swift`
  - Every view that reads `model.isOpen`, `model.geometry`, `model.panelSize` or `model.maxPanelSize`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `ScreenProvider` (MainActor):
    - `static func current() -> [(info: ScreenInfo, screen: NSScreen)]`. The id is the display UUID string from `NSScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]`. `isBuiltIn` comes from `CGDisplayIsBuiltin`. `isMain` means the screen is `NSScreen.screens.first`. `hasNotch` means a top safe-area inset and both auxiliary areas are present.
    - `static func geometry(for screen: NSScreen) -> NotchGeometry` returns the hardware `make(...)` result when there is a notch, else `.virtual(screenFrame:menuBarHeight:)` with the fallback `NSStatusBar.system.thickness`.
  - `NotchViewModel`:
    - `isOpen: Bool` becomes `private(set) var openScreenID: String?`, with `func isOpen(on id: String) -> Bool`.
    - `panelWillOpen(on id: String, fromBubble:)` and `panelDidClose(on id: String)`.
    - `panelSize(for g: NotchGeometry)` and `maxPanelSize(for g: NotchGeometry)` use `g.notch.height`.
    - `geometry` is removed from the model.
    - Everything else stays shared: modules, selected tab, `showsAll`, `isDraggingFile`, `closedLayout`, `closedWings` and accent.
  - `NotchWindowController(model:screenID:geometry:)`:
    - `func update(geometry:)` re-frames the window.
    - `func closeNow()` and `func tearDown()`: tearDown removes monitors and orders the panel out.
    - It opens only if `model.openScreenID` is nil or itself. Hover triggers when closed use `geometry.closedTriggerRect(model.closedWings)` (plus the bubble).
  - The root view takes `NotchRootView(model:, screenID:, geometry:)` (or a small observable `ScreenContext`) instead of reading geometry from the model.
  - `ScreenCoordinator(model:settings:)`:
    - observes `didChangeScreenParametersNotification` and the settings `screenMode` and `chosenScreenID` (observation re-arm);
    - computes `ScreenSelection.targets`, then creates, updates or tears down controllers by id;
    - clears `model.openScreenID` if its screen disappears;
    - `func closeAll()`.
  - AppDelegate wires `onOpenSettings` to `coordinator.closeAll()` and then `settingsWindow.show()`.

- [ ] **Step 1: Implement**, keeping the default mode (`.builtIn`) pixel-identical to 0.3 on a notched MacBook. Remove the old static `notchGeometry()` and the `"Built-in"` name check.
- [ ] **Step 2: Verify.**
  - `make test` passes and `make app` builds. `make run` does not crash.
  - With only the MacBook screen, behaviour is unchanged.
  - Set `screenMode` to all with `defaults write` (or the Task 5 UI later). On an external screen, a window exists, framed at its top centre: log the frames with `.public` geometry only.
  - Unplugging or replugging while open is a manual check for the user.
- [ ] **Step 3: Commit** `feat: one notch window per selected screen`.

### Task 4: Idle bar and pill on virtual notches

**Files:**
- Modify:
  - `Sources/IleDelbe/Views/NotchRootView.swift`
  - `Sources/IleDelbe/Views/ClosedActivityView.swift` if needed
  - `Sources/IleDelbe/Views/NotchShape.swift` if needed
- Test: none new in Core (geometry already covered); `#Preview`s for virtual idle bar, virtual pill with media, virtual alert.

**Interfaces:**
- Consumes: `geometry.isVirtual`, `closedShapeRect`, `closedOffsetX`.
- Produces: no new API.

Behaviour:
- On a virtual notch with `.plain`, draw only the thin black bar (`idleBarRect` size, bottom corners rounded about 2 pt, no halo).
- With any other layout, draw the pill exactly as on hardware (180 pt black centre plus wings, bubble, alert, title mode), at the screen's menu-bar height.
- Bar ↔ pill ↔ open panel transitions use the existing spring.
- Hardware notches are unchanged.

- [ ] **Step 1: Implement**, with previews.
- [ ] **Step 2: Verify.** `make test` passes, `make app` builds. Snapshot the previews (temporary hook allowed, not committed) or via `ReadmeAssets` to check that the bar is 120 × 4 and the pill aligns.
- [ ] **Step 3: Commit** `feat: thin idle bar and activity pill on external screens`.

### Task 5: « Écrans » setting

**Files:**
- Modify: `Sources/IleDelbe/Views/Settings/SettingsView.swift`, `Sources/IleDelbe/App/SettingsWindowController.swift` if the window height needs to change.

**Interfaces:**
- Consumes: `ScreenProvider.current()`, `AppSettings.screenMode` and `chosenScreenID`.

Behaviour:
- A new « Écrans » section at the top of the window, with a picker « Écran intégré », « Écran principal », « Un écran au choix », « Tous les écrans ».
- When « Un écran au choix » is selected, a second picker lists the connected screens by name (« Écran intégré » for the built-in one). Choosing a screen stores its id.
- If the stored screen is not connected, the picker shows « <nom inconnu> (débranché) » as the selected item, and the line « L'encoche est affichée sur l'écran de repli tant qu'il est débranché. ».
- The list refreshes on `didChangeScreenParametersNotification` while the window is open.

- [ ] **Step 1: Implement** (`#Preview` with a fake list of 3 screens).
- [ ] **Step 2: Verify.** `make test` passes and `make app` builds. With `make run`, changing the mode applies at once (the coordinator observes settings).
- [ ] **Step 3: Commit** `feat: Écrans setting with screen picker`.

### Task 6: README, CHANGELOG, version 0.4.0

**Files:**
- Modify: `Sources/IleDelbe/App/ReadmeAssets.swift`, `Readme.md`, `CHANGELOG.md`, `Resources/Info.plist`, `Sources/IleDelbeCore/IleDelbeCore.swift`, `Tests/IleDelbeCoreTests/SmokeTests.swift`, `packaging/homebrew/iledelbe.rb`, `docs/assets/`

- [ ] **Step 1: Update** the version test to `0.4.0`, see it fail, then bump `IleDelbeCore.version`, `Info.plist` (0.4.0 / 4) and the cask version, and see it pass.
- [ ] **Step 2: Add `external-screen.png` to `ReadmeAssets`.** It shows an external-screen menu bar (fake « Éditeur » app, no Apple logo) with the thin idle bar, and a second state with the media pill. Update the settings look-alike with the « Écrans » row. Run `make readme-assets`, then open the PNGs to check them.
- [ ] **Step 3: Update the docs.**
  - README: an « External screens » section explaining the 4 modes, the idle bar and the pill, and that the default is the built-in screen.
  - CHANGELOG: `## [0.4.0] - 2026-11-10` with compare links; note that Rail moves to a later version.
- [ ] **Step 4: Verify.** `make test` passes, `make app` builds, and every README image path exists.
- [ ] **Step 5: Commit** `docs: 0.4.0 external screens, changelog, version bump`.
