import Foundation

/// Every status the app can show. Later phases (calendar, OOO, commuting)
/// reuse these same values, so the list is complete from Phase 1.
enum StatusKind: String, CaseIterable, Codable, Identifiable {
    case outOfOffice
    case inCall
    case inMeeting
    case commuting
    case lunch
    case focus
    case away
    case active

    var id: String { rawValue }

    var label: String {
        switch self {
        case .outOfOffice: return "Out of office"
        case .inCall: return "In a call"
        case .inMeeting: return "In a meeting"
        case .commuting: return "Commuting"
        case .lunch: return "Lunch break"
        case .focus: return "Focus time"
        case .away: return "Away"
        case .active: return "Available"
        }
    }

    var emoji: String {
        switch self {
        case .outOfOffice: return "🌴"
        case .inCall: return "🎧"
        case .inMeeting: return "📅"
        case .commuting: return "🚗"
        case .lunch: return "🍽️"
        case .focus: return "🎯"
        case .away: return "💤"
        case .active: return "🟢"
        }
    }

    /// Statuses a person can pick by hand from the menu.
    static let manualOptions: [StatusKind] = [.inMeeting, .lunch, .focus, .commuting, .away, .outOfOffice]
}

enum StatusSource: Equatable {
    case automatic
    case manual
}

/// The single status the app is showing right now.
struct ResolvedStatus: Equatable {
    var kind: StatusKind
    var text: String
    var source: StatusSource
    var expiresAt: Date?
}

/// A status the person set by hand. It wins over all automatic detection until it expires.
struct ManualStatus: Codable, Equatable {
    var kind: StatusKind
    var customText: String?
    var expiresAt: Date?

    var displayText: String {
        let trimmed = customText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? kind.label : trimmed
    }
}

enum ManualDuration: String, CaseIterable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case endOfDay
    case untilChanged

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .endOfDay: return "End of day"
        case .untilChanged: return "Until I change it"
        }
    }

    func expiry(from now: Date, workdayEndHour: Int) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .thirtyMinutes: return now.addingTimeInterval(30 * 60)
        case .oneHour: return now.addingTimeInterval(60 * 60)
        case .twoHours: return now.addingTimeInterval(2 * 60 * 60)
        case .endOfDay:
            let workdayEnd = calendar.date(bySettingHour: workdayEndHour, minute: 0, second: 0, of: now) ?? now
            if workdayEnd > now { return workdayEnd }
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)
        case .untilChanged: return nil
        }
    }
}

/// Everything the person can tune. Each signal can be switched off on its own.
struct AutoStatusSettings: Codable, Equatable {
    var autoEnabled = true
    var detectCalls = true
    var detectAway = true
    var detectLunch = true
    var lunchStartMinutes = 13 * 60   // 1:00 PM
    var lunchEndMinutes = 14 * 60     // 2:00 PM
    var awayAfterMinutes = 10
    var lunchIdleAfterMinutes = 5
    var changeDelaySeconds = 20       // prevents flicker on short screen locks
    var workdayEndHour = 18
}

/// Raw readings from the Mac. Only the final label ever leaves the device.
struct SystemSignals: Equatable {
    var micInUse = false
    var cameraInUse = false
    var idleSeconds: TimeInterval = 0
    var screenLocked = false
    var displayAsleep = false
}
