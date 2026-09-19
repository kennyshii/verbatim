import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if app.currentUser == nil {
            LoginView()
        } else {
            NavigationStack(path: $app.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .debateSetup(let topic):
                            DebateSetupView(initialTopic: topic)
                        case .onlineSession(let code, let playerId):
                            OnlineSessionView(code: code, playerId: playerId)
                        case .congress:
                            CongressView()
                        case .committee(let committee):
                            CommitteeDetailView(committee: committee)
                        case .session(let config):
                            PracticeSessionView(config: config)
                        case .feedback(let config, let transcript):
                            FeedbackView(config: config, transcript: transcript)
                        case .dashboard:
                            ProgressDashboardView()
                        case .sessionDetail(let session):
                            SessionDetailView(session: session)
                        }
                    }
            }
        }
    }
}
