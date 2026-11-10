import AppKit
import IleDelbeCore
import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItemService
    @State private var screens = ScreensModel()

    private func bind<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { store.settings[keyPath: keyPath] = $0 })
    }

    var body: some View {
        let s = store.settings
        Form {
            ScreensSection(mode: screenModeBinding, chosenID: chosenIDBinding,
                           chosenName: s.chosenScreenName, choices: screens.choices)

            Section {
                Picker("Style", selection: bind(\.style)) {
                    Text("Île").tag(PanelStyle.island)
                    Text("Grille").tag(PanelStyle.grid)
                    Text("Onglets").tag(PanelStyle.tabs)
                }.pickerStyle(.segmented)

                Picker("Couleur", selection: bind(\.accent)) {
                    Text("Pochette").tag(AccentSource.artwork)
                    Text("Fixe").tag(AccentSource.fixed)
                    Text("Aucune").tag(AccentSource.none)
                }.pickerStyle(.segmented)
                if s.accent == .fixed {
                    LabeledContent("Teinte") {
                        HStack(spacing: 10) {
                            ForEach(FixedTint.allCases, id: \.self) { tint in swatch(tint, selected: s.fixedTint == tint) }
                        }
                    }
                }

                LabeledContent("Intensité du halo") {
                    HStack {
                        Slider(value: bind(\.haloIntensity), in: 0...1, step: 0.05).frame(width: 160)
                        Text("\(Int((s.haloIntensity * 100).rounded())) %")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section("Modules") {
                ForEach(Array(s.modules.enumerated()), id: \.element.module) { index, entry in
                    HStack {
                        Toggle(entry.module.title, isOn: Binding(
                            get: { entry.visible },
                            set: { store.settings.setVisible(entry.module, $0) }))
                        Spacer()
                        Button { store.settings.moveModule(from: index, to: index - 1) } label: {
                            Image(systemName: "chevron.up")
                        }.disabled(index == 0).accessibilityLabel("Monter \(entry.module.title)")
                        Button { store.settings.moveModule(from: index, to: index + 1) } label: {
                            Image(systemName: "chevron.down")
                        }.disabled(index == s.modules.count - 1).accessibilityLabel("Descendre \(entry.module.title)")
                    }.buttonStyle(.borderless)
                }
                Picker("À l'ouverture", selection: bind(\.forcedModule)) {
                    Text("Automatique").tag(PanelTab?.none)
                    ForEach(s.visibleModules, id: \.self) { Text($0.title).tag(PanelTab?.some($0)) }
                }
            }

            Section {
                Picker("Encoche fermée pendant la lecture", selection: bind(\.closedStyle)) {
                    Text("Pochette + égaliseur").tag(ClosedStyle.artworkEqualizer)
                    Text("Titre").tag(ClosedStyle.title)
                    Text("Rien").tag(ClosedStyle.none)
                }.pickerStyle(.menu)
                Toggle("Animer l'encoche fermée", isOn: bind(\.animateClosed))
                LabeledContent("Délai d'ouverture au survol") {
                    HStack {
                        Slider(value: bind(\.openDelay), in: 0.05...0.6, step: 0.05).frame(width: 160)
                        Text(Self.delayText(s.openDelay)).monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section {
                LabeledContent("Durées du minuteur") {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            Stepper(value: presetBinding(i), in: 1...180) {
                                Text("\(s.timerPresetsMinutes[i]) min").monospacedDigit()
                            }
                        }
                    }
                }
                Picker("Taille du panneau", selection: bind(\.density)) {
                    Text("Normale").tag(PanelDensity.normal)
                    Text("Compacte").tag(PanelDensity.compact)
                }.pickerStyle(.segmented)
                Picker("Fichiers récents", selection: bind(\.recentFileCount)) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                }.pickerStyle(.segmented)
            }

            Section {
                Toggle("Lancer à l'ouverture de session", isOn: Binding(
                    get: { loginItem.isEnabled || loginItem.needsApproval },
                    set: { loginItem.set($0) }))
                if loginItem.needsApproval {
                    Text("À approuver dans Réglages Système › Général › Ouverture")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        // The grouped Form scrolls: ~700 pt fits a 1280×800 display, and the window can be
        // resized vertically (`SettingsWindowController`) down to the minimum or up to the full list.
        .frame(width: 520)
        .frame(minHeight: Self.minHeight, idealHeight: Self.idealHeight, maxHeight: .infinity)
    }

    static let minHeight: CGFloat = 420
    static let idealHeight: CGFloat = 700

    /// Switching to « Un écran au choix » with nothing stored picks a sensible screen right away.
    private var screenModeBinding: Binding<ScreenMode> {
        Binding(get: { store.settings.screenMode },
                set: { mode in
                    store.settings.screenMode = mode
                    if mode == .chosen, store.settings.chosenScreenID == nil,
                       let first = ScreenChoice.defaultChoice(in: screens.choices) {
                        store.settings.chosenScreenID = first.id
                        store.settings.chosenScreenName = first.label
                    }
                })
    }

    /// Picking a screen also stores its name, shown as « <nom> (débranché) » while it is unplugged.
    private var chosenIDBinding: Binding<String?> {
        Binding(get: { store.settings.chosenScreenID },
                set: { id in
                    store.settings.chosenScreenID = id
                    if let choice = screens.choices.first(where: { $0.id == id }) {
                        store.settings.chosenScreenName = choice.label
                    }
                })
    }

    private func presetBinding(_ i: Int) -> Binding<Int> {
        Binding(get: { store.settings.timerPresetsMinutes[i] },
                set: { store.settings.timerPresetsMinutes[i] = $0 })
    }

    private func swatch(_ tint: FixedTint, selected: Bool) -> some View {
        Button { store.settings.fixedTint = tint } label: {
            Circle().fill(Color(hex: tint.hex) ?? .gray).frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 1))
                .overlay(Circle().strokeBorder(.primary, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.tintName(tint))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    static func tintName(_ tint: FixedTint) -> String {
        switch tint {
        case .blue: "Bleu"
        case .green: "Vert"
        case .violet: "Violet"
        case .yellow: "Jaune"
        case .white: "Blanc"
        }
    }

    /// « 0,15 s », always with the French decimal comma.
    static func delayText(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",") + " s"
    }
}

/// One connected screen as shown in the picker.
struct ScreenChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let isBuiltIn: Bool

    /// « Écran intégré » for the built-in screen, else the screen name; repeated names get « (2) », « (3) ».
    /// A repeated id is dropped (`ScreenProvider` already makes ids unique; `ForEach` needs it).
    static func make(from infos: [ScreenInfo]) -> [ScreenChoice] {
        var seen: [String: Int] = [:]
        var ids = Set<String>()
        return infos.filter { ids.insert($0.id).inserted }.map { info in
            let base = info.isBuiltIn ? "Écran intégré" : info.name
            let count = (seen[base] ?? 0) + 1
            seen[base] = count
            return ScreenChoice(id: info.id, label: count == 1 ? base : "\(base) (\(count))", isBuiltIn: info.isBuiltIn)
        }
    }

    /// The first external screen if any, else the first one.
    static func defaultChoice(in choices: [ScreenChoice]) -> ScreenChoice? {
        choices.first { !$0.isBuiltIn } ?? choices.first
    }
}

/// The connected screens, refreshed when the display configuration changes (no polling).
@MainActor @Observable
final class ScreensModel {
    private(set) var choices: [ScreenChoice]
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        choices = ScreenChoice.make(from: ScreenProvider.current().map(\.info))
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.choices = ScreenChoice.make(from: ScreenProvider.current().map(\.info))
            }
        }
    }

    isolated deinit { observer.map(NotificationCenter.default.removeObserver) }
}

/// The « Écrans » section, driven by plain values so a preview can feed it a fake list.
struct ScreensSection: View {
    @Binding var mode: ScreenMode
    @Binding var chosenID: String?
    /// The stored name of the chosen screen (`AppSettings.chosenScreenName`), for the unplugged label.
    let chosenName: String?
    let choices: [ScreenChoice]

    private var chosenIsConnected: Bool { chosenID.map { id in choices.contains { $0.id == id } } ?? true }

    var body: some View {
        Section("Écrans") {
            Picker("Afficher l'encoche sur", selection: $mode) {
                Text("Écran intégré").tag(ScreenMode.builtIn)
                Text("Écran principal").tag(ScreenMode.main)
                Text("Un écran au choix").tag(ScreenMode.chosen)
                Text("Tous les écrans").tag(ScreenMode.all)
            }
            if mode == .chosen {
                Picker("Écran", selection: $chosenID) {
                    if !chosenIsConnected {
                        Text("\(chosenName ?? "<nom inconnu>") (débranché)").tag(chosenID)
                    }
                    ForEach(choices) { Text($0.label).tag(String?.some($0.id)) }
                }
                if !chosenIsConnected {
                    Text("L'encoche est affichée sur l'écran de repli tant qu'il est débranché.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Écrans") {
    @Previewable @State var mode = ScreenMode.chosen
    @Previewable @State var id: String? = "b"
    Form {
        ScreensSection(mode: $mode, chosenID: $id, chosenName: "DELL U2723QE", choices: [
            ScreenChoice(id: "a", label: "Écran intégré", isBuiltIn: true),
            ScreenChoice(id: "b", label: "DELL U2723QE", isBuiltIn: false),
            ScreenChoice(id: "c", label: "DELL U2723QE (2)", isBuiltIn: false)])
    }.formStyle(.grouped).frame(width: 520, height: 260)
}

#Preview {
    SettingsView(store: SettingsStore(defaults: UserDefaults(suiteName: "preview")!), loginItem: LoginItemService())
}
#endif
