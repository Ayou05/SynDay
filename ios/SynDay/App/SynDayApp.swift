import SwiftUI

@main
struct SynDayApp: App {
    @State private var authManager = AuthManager.shared

    init() {
        configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { await authManager.bootstrap() }
        }
    }

    private struct RootView: View {
        @State private var authManager = AuthManager.shared
        var body: some View {
            switch authManager.state {
            case .unknown:
                SplashView()
            case .unauthenticated:
                AuthFlowView()
            case .authenticated:
                MainTabView()
            }
        }
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(named: "Forest")
    }
}
