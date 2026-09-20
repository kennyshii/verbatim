import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            if app.currentUser == nil {
                LoginView()
            } else {
                TabView(selection: $app.tab) {
                    NavigationStack(path: $app.practicePath) {
                        HomeView().appRoutes()
                    }
                    .tabItem { Label("Debate", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(AppTab.practice)

                    NavigationStack(path: $app.congressPath) {
                        CongressView().appRoutes()
                    }
                    .tabItem { Label("Congress", systemImage: "building.columns.fill") }
                    .tag(AppTab.congress)

                    NavigationStack(path: $app.progressPath) {
                        ProgressDashboardView().appRoutes()
                    }
                    .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                    .tag(AppTab.progress)

                    NavigationStack {
                        SettingsView(embedded: true)
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
                }
                .tint(Theme.accent)
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension View {
    func appRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .debateSetup(let topic):
                DebateSetupView(initialTopic: topic)
            case .debateSetupMode(let mode):
                DebateSetupView(initialMode: mode)
            case .onlineSession(let code, let playerId):
                OnlineSessionView(code: code, playerId: playerId)
            case .committee(let committee):
                CommitteeDetailView(committee: committee)
            case .session(let config):
                PracticeSessionView(config: config)
            case .feedback(let config, let transcript):
                FeedbackView(config: config, transcript: transcript)
            case .sessionDetail(let session):
                SessionDetailView(session: session)
            }
        }
    }
}
