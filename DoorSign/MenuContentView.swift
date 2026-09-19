import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var engine: StatusEngine

    @State private var duration: ManualDuration = .oneHour
    @State private var customText = ""
    @State private var showSettings = false
    @State private var showSignals = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            quickStatuses
            Divider()
            Toggle("Automatic status", isOn: $engine.settings.autoEnabled)
            DisclosureGroup("Detection settings", isExpanded: $showSettings) {
                settingsSection.padding(.top, 6)
            }
            DisclosureGroup("What the app detects", isExpanded: $showSignals) {
                signalsSection.padding(.top, 6)
            }
            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    // MARK: Current status

    private var header: some View {
        HStack(spacing: 10) {
            Text(engine.current.kind.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.current.text).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if engine.current.source == .manual {
                Button("Clear") { engine.clearManual() }
            }
        }
    }

    private var subtitle: String {
        if engine.current.source == .manual {
            guard let expiry = engine.current.expiresAt else { return "Set by you until you change it" }
            return "Set by you until \(expiry.formatted(date: .omitted, time: .shortened))"
        }
        return engine.settings.autoEnabled ? "Detected automatically" : "Automatic status is paused"
    }

    // MARK: Manual statuses

    private var quickStatuses: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set a status").font(.subheadline).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(StatusKind.manualOptions) { kind in
                    Button {
                        engine.setManual(kind, text: customText, duration: duration)
                        customText = ""
                    } label: {
                        HStack(spacing: 6) {
                            Text(kind.emoji)
                            Text(kind.label).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            TextField("Custom message (optional)", text: $customText)
                .textFieldStyle(.roundedBorder)

            Picker("Clear after", selection: $duration) {
                ForEach(ManualDuration.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Detect calls (mic or camera in use)", isOn: $engine.settings.detectCalls)
            Toggle("Detect away (locked or idle)", isOn: $engine.settings.detectAway)
            Toggle("Detect lunch break", isOn: $engine.settings.detectLunch)

            HStack {
                Text("Lunch")
                Spacer()
                DatePicker("", selection: timeBinding(\.lunchStartMinutes), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("to")
                DatePicker("", selection: timeBinding(\.lunchEndMinutes), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .disabled(!engine.settings.detectLunch)

            Stepper("Away after \(engine.settings.awayAfterMinutes) min idle",
                    value: $engine.settings.awayAfterMinutes, in: 2...60)
            Stepper("Lunch after \(engine.settings.lunchIdleAfterMinutes) min idle",
                    value: $engine.settings.lunchIdleAfterMinutes, in: 1...30)
            Stepper("Change delay \(engine.settings.changeDelaySeconds) sec",
                    value: $engine.settings.changeDelaySeconds, in: 0...120, step: 5)
        }
        .disabled(!engine.settings.autoEnabled)
    }

    private func timeBinding(_ keyPath: WritableKeyPath<AutoStatusSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = engine.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                engine.settings[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: Transparency

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            signalRow("Microphone in use", engine.signals.micInUse ? "Yes" : "No")
            signalRow("Camera in use", engine.signals.cameraInUse ? "Yes" : "No")
            signalRow("Screen locked", engine.signals.screenLocked ? "Yes" : "No")
            signalRow("Display asleep", engine.signals.displayAsleep ? "Yes" : "No")
            signalRow("Idle for", idleText)
            if let pending = engine.pendingKind {
                signalRow("Changing to", "\(pending.emoji) \(pending.label)")
            }
            Text("Only the final status label is shared. Raw readings stay on this Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.caption)
    }

    private var idleText: String {
        let seconds = Int(engine.signals.idleSeconds)
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }

    private func signalRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
