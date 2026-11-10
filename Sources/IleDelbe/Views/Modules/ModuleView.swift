import AppKit
import IleDelbeCore
import SwiftUI

/// One module at one size, wired to the services. The only module view that reads the model:
/// the size views take plain values and closures (so `ReadmeAssets` renders them with samples).
struct ModuleView: View {
    let module: PanelTab
    let size: ModuleSize
    let model: NotchViewModel

    var body: some View {
        switch module {
        case .music: music
        case .timer: timer
        case .agenda: agenda
        case .files: files
        }
    }

    @ViewBuilder
    private var music: some View {
        let info = model.nowPlaying.info
        let history = model.history.history.recent(excluding: info)
        let onCommand: (AdapterCommand) -> Void = { model.nowPlaying.send($0) }
        let onVolume: (Float) -> Void = { model.volume.set($0) }
        switch size {
        case .compact:
            MusicCompactView(info: info, glow: model.accent, haloScale: model.haloOpacityScale, onCommand: onCommand)
        case .card:
            MusicCardView(info: info, history: history, glow: model.accent, haloScale: model.haloOpacityScale,
                          volume: model.volume.volume, isVolumeSettable: model.volume.isSettable,
                          onCommand: onCommand, onVolume: onVolume)
        case .full:
            MusicPaneView(info: info, history: history, glow: model.accent, haloScale: model.haloOpacityScale,
                          volume: model.volume.volume, isVolumeSettable: model.volume.isSettable,
                          onCommand: onCommand, onVolume: onVolume)
        }
    }

    @ViewBuilder
    private var timer: some View {
        let service = model.timer
        let presets = model.settings.settings.timerPresetsMinutes
        let onStart: (TimeInterval) -> Void = { service.start($0) }
        let onAddMinute = { service.addMinute() }
        let onPause = { service.pause() }
        let onResume = { service.resume() }
        let onStop = { service.stop() }
        let onAcknowledge = { service.acknowledge() }
        switch size {
        case .compact:
            TimerCompactView(timer: service.timer, now: service.now, presetsMinutes: presets, onStart: onStart,
                             onAddMinute: onAddMinute, onPause: onPause, onResume: onResume, onStop: onStop,
                             onAcknowledge: onAcknowledge)
        case .card:
            TimerCardView(timer: service.timer, now: service.now, presetsMinutes: presets, onStart: onStart,
                          onAddMinute: onAddMinute, onPause: onPause, onResume: onResume, onStop: onStop,
                          onAcknowledge: onAcknowledge)
        case .full:
            TimerPaneView(timer: service.timer, now: service.now, presetsMinutes: presets, onStart: onStart,
                          onAddMinute: onAddMinute, onPause: onPause, onResume: onResume, onStop: onStop,
                          onAcknowledge: onAcknowledge)
        }
    }

    @ViewBuilder
    private var agenda: some View {
        let calendar = model.calendar
        let onAppear = { calendar.requestAccessIfNeeded() }
        let onJoin: (URL) -> Void = { NSWorkspace.shared.open($0) }
        let onOpenSettings = { calendar.openPrivacySettings() }
        switch size {
        case .compact:
            AgendaCompactView(access: calendar.access, events: calendar.upcoming, now: Date(), accent: model.accent,
                              onAppear: onAppear, onJoin: onJoin, onOpenSettings: onOpenSettings)
        case .card:
            AgendaCardView(access: calendar.access, events: calendar.upcoming, now: Date(), accent: model.accent,
                           onAppear: onAppear, onJoin: onJoin, onOpenSettings: onOpenSettings)
        case .full:
            AgendaPaneView(access: calendar.access, events: calendar.upcoming, now: Date(),
                           onAppear: onAppear, onJoin: onJoin, onOpenSettings: onOpenSettings)
        }
    }

    @ViewBuilder
    private var files: some View {
        let service = model.files
        let count = model.settings.settings.recentFileCount
        let icon: (RecentFile) -> NSImage = { service.icon(for: $0) }
        let onOpen: (RecentFile) -> Void = { service.open($0) }
        let onDragStart = { model.isDraggingFile = true }
        switch size {
        case .compact:
            FilesCompactView(files: service.files, count: count, icon: icon, now: Date(), onOpen: onOpen,
                             onDragStart: onDragStart)
        case .card:
            FilesCardView(files: service.files, count: count, icon: icon, onOpen: onOpen, onDragStart: onDragStart)
        case .full:
            FilesPaneView(files: service.files, home: FileManager.default.homeDirectoryForCurrentUser, count: count,
                          icon: icon, now: Date(), onOpen: onOpen, onDragStart: onDragStart)
        }
    }
}
