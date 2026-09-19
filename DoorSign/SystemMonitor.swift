import AppKit
import CoreGraphics

/// Tracks screen lock and display sleep through system notifications,
/// and reads idle time (seconds since the last keyboard or mouse input).
final class SystemMonitor {
    private(set) var screenLocked = false
    private(set) var displayAsleep = false

    private var distributedTokens: [NSObjectProtocol] = []
    private var workspaceTokens: [NSObjectProtocol] = []

    init() {
        let distributed = DistributedNotificationCenter.default()
        distributedTokens = [
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                self?.screenLocked = true
            },
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                self?.screenLocked = false
            }
        ]

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceTokens = [
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displayAsleep = true
            },
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displayAsleep = false
            },
            workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displayAsleep = true
            },
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displayAsleep = false
            }
        ]
    }

    deinit {
        distributedTokens.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func idleSeconds() -> TimeInterval {
        // rawValue ~0 means "any input event".
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
