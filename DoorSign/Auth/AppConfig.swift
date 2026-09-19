import Foundation

/// Build configuration that must not be committed to git.
///
/// Values live in `Secrets.xcconfig` (gitignored), are referenced from
/// `Info.plist`, and are read back here at runtime. An unset key still holds
/// its literal `$(NAME)` placeholder, which is treated as missing.
enum AppConfig {

    /// OAuth client ID from the Google Cloud project, type macOS.
    static var googleClientID: String? { string("GIDClientID") }

    /// True once the app has enough configuration to attempt sign-in.
    static var isGoogleConfigured: Bool { googleClientID != nil }

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
