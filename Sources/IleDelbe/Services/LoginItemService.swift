import Foundation
import Observation
import ServiceManagement
import os

/// Launch at login through `SMAppService.mainApp`. Nothing is registered until `set(_:)` is called.
@MainActor @Observable
final class LoginItemService {
    private(set) var status: SMAppService.Status
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "login-item")

    init() { status = SMAppService.mainApp.status }

    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }

    /// Re-reads the status, e.g. when the settings window appears (the user may have changed it in System Settings).
    func refresh() { status = SMAppService.mainApp.status }

    func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("login item \(on ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .private)")
        }
        refresh()
    }
}
