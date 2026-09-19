import SwiftUI

@main
struct DoorSignApp: App {
    @StateObject private var engine = StatusEngine()
    @StateObject private var auth = GoogleAuth()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(engine)
                .environmentObject(auth)
        } label: {
            Text(engine.current.kind.emoji)
        }
        .menuBarExtraStyle(.window)
    }
}
