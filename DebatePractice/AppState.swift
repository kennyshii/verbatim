import Foundation
import SwiftUI

enum Route: Hashable {
    case debateSetup(String?)
    case debateSetupMode(SessionMode)
    case onlineSession(String, String)
    case committee(Committee)
    case session(PracticeConfig)
    case feedback(PracticeConfig, [ChatMessage])
    case sessionDetail(SessionRecord)
}

enum AppTab: Hashable {
    case practice
    case congress
    case progress
    case settings
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var tab: AppTab = .practice
    @Published var practicePath = NavigationPath()
    @Published var congressPath = NavigationPath()
    @Published var progressPath = NavigationPath()
    @Published private(set) var hasAPIKey: Bool = (Keychain.loadAPIKey() ?? "").isEmpty == false

    @AppStorage("support.lowPressure") var lowPressure = false
    @AppStorage("support.readAloud") var readAloud = false
    @AppStorage("support.plainLanguage") var plainLanguage = false
    @AppStorage("support.showFillerMeter") var showFillerMeter = true

    let db = Database.shared
    lazy var auth = AuthStore(db: db)
    lazy var sessions = SessionStore(db: db)
    let claude = ClaudeClient()

    func push(_ route: Route) {
        switch tab {
        case .practice: practicePath.append(route)
        case .congress: congressPath.append(route)
        case .progress: progressPath.append(route)
        case .settings: tab = .practice; practicePath.append(route)
        }
    }

    func setAPIKey(_ key: String) {
        Keychain.saveAPIKey(key)
        hasAPIKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func logout() {
        currentUser = nil
        goHome()
        tab = .practice
    }

    func goHome() {
        practicePath = NavigationPath()
        congressPath = NavigationPath()
        progressPath = NavigationPath()
    }
}
