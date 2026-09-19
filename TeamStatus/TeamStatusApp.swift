import SwiftUI

@main
struct TeamStatusApp: App {
    @StateObject private var engine = StatusEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(engine)
        } label: {
            Text(engine.current.kind.emoji)
        }
        .menuBarExtraStyle(.window)
    }
}
