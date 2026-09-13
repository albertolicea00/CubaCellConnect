import SwiftUI

@main
struct CubaCellConnectApp: App {
    @State private var store = USSDCodeStore()
    @State private var accentColorStore = AccentColorStore()
    @AppStorage("darkModePreference") private var darkModePreference: Int = 0

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .environment(accentColorStore)
                .tint(accentColorStore.color)
                .preferredColorScheme(darkModePreference == 1 ? .light : (darkModePreference == 2 ? .dark : nil))
        }
    }
}
