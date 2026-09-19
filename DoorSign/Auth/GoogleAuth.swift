import AppKit
import Combine
import GoogleSignIn

/// Owns the Google sign-in session.
///
/// Slice 2a only establishes who the person is. The Chat and Calendar scopes
/// are requested later, by the slices that actually need them, so nobody is
/// asked to grant access to something the app cannot yet use.
@MainActor
final class GoogleAuth: ObservableObject {

    enum State: Equatable {
        case notConfigured
        case signedOut
        case signingIn
        case signedIn(email: String)
        case failed(String)
    }

    @Published private(set) var state: State = .signedOut

    private var anchor: NSWindow?

    init() {
        guard let clientID = AppConfig.googleClientID else {
            state = .notConfigured
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        restore()
    }

    /// Silently reuses a previous session so the person signs in once, not once per launch.
    private func restore() {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            state = .signedOut
            return
        }
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            Task { @MainActor in
                guard let self else { return }
                if let email = user?.profile?.email {
                    self.state = .signedIn(email: email)
                } else {
                    // A revoked or expired grant is a normal signed-out state,
                    // not an error worth showing.
                    self.state = .signedOut
                    _ = error
                }
            }
        }
    }

    func signIn() {
        guard AppConfig.isGoogleConfigured else {
            state = .notConfigured
            return
        }
        state = .signingIn

        // An agent app is never frontmost, so the consent window would open
        // behind everything without this.
        NSApp.activate(ignoringOtherApps: true)

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow()) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                self.releaseAnchor()
                if let email = result?.user.profile?.email {
                    self.state = .signedIn(email: email)
                } else if let error, (error as NSError).code == GIDSignInError.canceled.rawValue {
                    self.state = .signedOut
                } else {
                    self.state = .failed(error?.localizedDescription ?? "Sign-in failed")
                }
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        state = .signedOut
    }

    // MARK: Presentation

    /// GoogleSignIn needs a window to anchor the consent sheet to. A menubar
    /// agent app has none of its own, so borrow the panel if it is open and
    /// fall back to a small window created for the purpose.
    private func presentingWindow() -> NSWindow {
        if let visible = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            return visible
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 1),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to DoorSign"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        anchor = window
        return window
    }

    private func releaseAnchor() {
        anchor?.close()
        anchor = nil
    }
}
