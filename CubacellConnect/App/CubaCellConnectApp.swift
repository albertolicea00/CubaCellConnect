import SwiftUI

@main
struct CubaCellConnectApp: App {
    @State private var store = USSDCodeStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
