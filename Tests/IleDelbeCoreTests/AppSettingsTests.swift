import Testing
import Foundation
@testable import IleDelbeCore

@Suite struct AppSettingsTests {
    @Test func defaults() {
        let s = AppSettings.default
        #expect(s.style == .island && s.accent == .artwork && s.haloIntensity == 0.6)
        #expect(s.visibleModules == [.music, .timer, .agenda, .files])
        #expect(s.openDelay == 0.15 && s.timerPresetsMinutes == [5, 10, 25] && s.recentFileCount == 3)
        #expect(s.closedStyle == .artworkEqualizer && s.density == .normal && s.forcedModule == nil)
        #expect(s.animateClosed)
    }
    @Test func screenDefaultsAndFallback() {
        #expect(AppSettings.default.screenMode == .builtIn && AppSettings.default.chosenScreenID == nil)
        let s = AppSettings.load(Data(#"{"screenMode":"mirror","chosenScreenID":"C","style":"grid"}"#.utf8))
        #expect(s.screenMode == .builtIn && s.chosenScreenID == "C" && s.style == .grid)
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
        #expect(s.style == .island)
        #expect(s.closedStyle == .title)
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
