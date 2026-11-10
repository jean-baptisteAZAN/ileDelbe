import Testing
@testable import IleDelbeCore

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
    @Test func noMainFlagAmongSeveralUsesFirst() {
        var d = dell; d.isMain = false
        #expect(ScreenSelection.targets([lg, d, mac], mode: .main, chosenID: nil) == ["C"])
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
