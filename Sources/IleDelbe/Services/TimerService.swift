import AppKit
import IleDelbeCore
import Observation
import os

/// Drives a `CountdownTimer`: persistence, the 1 s tick (only while active or ringing) and the ring sound.
@MainActor @Observable
final class TimerService {
    private(set) var timer: CountdownTimer
    private(set) var now: Date
    var ringingUnseen = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "timer")
    @ObservationIgnored private var ticker: Timer?
    private static let key = "timer.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let now = Date()
        var restored = CountdownTimer()
        if let data = defaults.data(forKey: Self.key) {
            do { restored = try JSONDecoder().decode(CountdownTimer.self, from: data) }
            catch { log.error("timer decode failed, resetting: \(error.localizedDescription)") }
        }
        restored.restoreAfterLaunch(now: now)
        self.timer = restored
        self.now = now
        persist()
        updateTicker()
    }

    func start(_ duration: TimeInterval) { mutate { $0.start(duration: duration, now: $1) } }
    func addMinute() { mutate { $0.addMinute(now: $1) } }
    func pause() { mutate { $0.pause(now: $1) } }
    func resume() { mutate { $0.resume(now: $1) } }
    func stop() { mutate { t, _ in t.stop() } }
    func acknowledge() { mutate { t, _ in t.acknowledge() } }

    private func mutate(_ change: (inout CountdownTimer, Date) -> Void) {
        let date = Date()
        now = date
        change(&timer, date)
        persist()
        updateTicker()
    }

    private func tick() {
        let date = Date()
        now = date
        let before = timer
        if timer.tick(now: date) {
            NSSound(named: "Glass")?.play()
            ringingUnseen = true
        }
        if timer != before { persist() }
        updateTicker()
    }

    private func updateTicker() {
        let needed: Bool = switch timer.state {
        case .running, .ringing: true
        default: false
        }
        if needed, ticker == nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            t.tolerance = 0.1
            RunLoop.main.add(t, forMode: .common)
            ticker = t
        } else if !needed, let t = ticker {
            t.invalidate()
            ticker = nil
        }
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(timer), forKey: Self.key) }
        catch { log.error("timer encode failed: \(error.localizedDescription)") }
    }
}
