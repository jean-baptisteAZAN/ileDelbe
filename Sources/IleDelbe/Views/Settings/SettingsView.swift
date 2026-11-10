import IleDelbeCore
import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItemService

    private func bind<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { store.settings[keyPath: keyPath] = $0 })
    }

    var body: some View {
        let s = store.settings
        Form {
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
                    Text("Pochette").tag(ClosedStyle.artworkEqualizer)
                    Text("Titre").tag(ClosedStyle.title)
                    Text("Rien").tag(ClosedStyle.none)
                }.pickerStyle(.segmented)
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
        .frame(width: 520, height: 700)
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

#if DEBUG
#Preview {
    SettingsView(store: SettingsStore(defaults: UserDefaults(suiteName: "preview")!), loginItem: LoginItemService())
}
#endif
