import SwiftUI

@main
struct EchoApp: App {
    @StateObject private var store = EchoStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { store.bootstrap() }
                .preferredColorScheme(.dark)
        }
    }
}
