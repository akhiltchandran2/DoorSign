import Foundation
import os

/// Where status changes are sent. Phase 1 only logs them.
/// Phase 2 adds a Google Chat publisher, Phase 3 adds the team board publisher.
protocol StatusPublisher {
    func publish(_ status: ResolvedStatus)
}

struct LogPublisher: StatusPublisher {
    private let logger = Logger(subsystem: "com.company.doorsign", category: "status")

    func publish(_ status: ResolvedStatus) {
        let source = status.source == .manual ? "manual" : "auto"
        logger.info("Status changed: \(status.kind.emoji, privacy: .public) \(status.text, privacy: .public) [\(source, privacy: .public)]")
    }
}
