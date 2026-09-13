import SwiftUI

@main
struct CubaCellConnectApp: App {
    @State private var store = USSDCodeStore()
    @AppStorage("darkModePreference") private var darkModePreference: Int = 0

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .preferredColorScheme(darkModePreference == 1 ? .light : (darkModePreference == 2 ? .dark : nil))
        }
    }
}
