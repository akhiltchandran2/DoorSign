import Foundation
import Combine

/// Combines system signals and the manual override into one status.
///
/// Priority (highest first):
/// 1. Manual status set from the menu (until it expires)
/// 2. In a call (mic or camera in use)
/// 3. Lunch (inside lunch window and locked or idle)
/// 4. Away (locked, display asleep, or idle too long)
/// 5. Available
///
/// Out of office, meetings, and commuting slot in above "In a call" in later phases.
@MainActor
final class StatusEngine: ObservableObject {
    @Published private(set) var current: ResolvedStatus
    @Published private(set) var signals = SystemSignals()
    @Published private(set) var pendingKind: StatusKind?

    @Published var manual: ManualStatus? {
        didSet {
            save(manual, key: Keys.manual)
            evaluate(immediate: true)
        }
    }

    @Published var settings: AutoStatusSettings {
        didSet {
            save(settings, key: Keys.settings)
            evaluate(immediate: true)
        }
    }

    private let callDetector = CallDetector()
    private let systemMonitor = SystemMonitor()
    private let publisher: StatusPublisher
    private var pendingSince: Date?
    private var timer: Timer?

    private enum Keys {
        static let manual = "manualStatus"
        static let settings = "autoStatusSettings"
    }

    init(publisher: StatusPublisher = LogPublisher()) {
        self.publisher = publisher
        self.settings = Self.load(AutoStatusSettings.self, key: Keys.settings) ?? AutoStatusSettings()
        self.manual = Self.load(ManualStatus.self, key: Keys.manual)
        self.current = ResolvedStatus(kind: .active, text: StatusKind.active.label, source: .automatic, expiresAt: nil)

        readSignals()
        evaluate(immediate: true)

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.readSignals()
                self?.evaluate(immediate: false)
            }
        }
    }

    // MARK: Actions from the menu

    func setManual(_ kind: StatusKind, text: String, duration: ManualDuration) {
        let expiry = duration.expiry(from: Date(), workdayEndHour: settings.workdayEndHour)
        manual = ManualStatus(kind: kind, customText: text, expiresAt: expiry)
    }

    func clearManual() {
        manual = nil
    }

    // MARK: Evaluation

    private func readSignals() {
        signals = SystemSignals(
            micInUse: settings.detectCalls && callDetector.isMicrophoneInUse(),
            cameraInUse: settings.detectCalls && callDetector.isCameraInUse(),
            idleSeconds: systemMonitor.idleSeconds(),
            screenLocked: systemMonitor.screenLocked,
            displayAsleep: systemMonitor.displayAsleep
        )
    }

    private func evaluate(immediate: Bool) {
        let now = Date()

        if let manual {
            if let expiry = manual.expiresAt, expiry <= now {
                self.manual = nil   // didSet re-runs evaluate
                return
            }
            clearPending()
            commit(ResolvedStatus(kind: manual.kind, text: manual.displayText, source: .manual, expiresAt: manual.expiresAt))
            return
        }

        let candidate = settings.autoEnabled ? automaticKind(at: now) : .active

        if immediate || current.source == .manual || candidate == current.kind {
            clearPending()
            commit(automatic(candidate))
            return
        }

        // Wait for the new state to hold before switching, so short screen locks do not flicker.
        if pendingKind == candidate, let since = pendingSince {
            if now.timeIntervalSince(since) >= TimeInterval(settings.changeDelaySeconds) {
                clearPending()
                commit(automatic(candidate))
            }
        } else {
            pendingKind = candidate
            pendingSince = now
        }
    }

    private func automaticKind(at now: Date) -> StatusKind {
        let s = signals
        let inactive = s.screenLocked || s.displayAsleep

        if settings.detectCalls && (s.micInUse || s.cameraInUse) {
            return .inCall
        }
        if settings.detectLunch && isInLunchWindow(now)
            && (inactive || s.idleSeconds >= TimeInterval(settings.lunchIdleAfterMinutes * 60)) {
            return .lunch
        }
        if settings.detectAway
            && (inactive || s.idleSeconds >= TimeInterval(settings.awayAfterMinutes * 60)) {
            return .away
        }
        return .active
    }

    private func isInLunchWindow(_ date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= settings.lunchStartMinutes && minutes < settings.lunchEndMinutes
    }

    private func automatic(_ kind: StatusKind) -> ResolvedStatus {
        ResolvedStatus(kind: kind, text: kind.label, source: .automatic, expiresAt: nil)
    }

    private func clearPending() {
        pendingKind = nil
        pendingSince = nil
    }

    private func commit(_ status: ResolvedStatus) {
        guard status != current else { return }
        current = status
        publisher.publish(status)
    }

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
