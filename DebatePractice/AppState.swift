import Foundation
import SwiftUI

enum Route: Hashable {
    case debateSetup(String?)
    case onlineSession(String, String)
    case congress
    case committee(Committee)
    case session(PracticeConfig)
    case feedback(PracticeConfig, [ChatMessage])
    case dashboard
    case sessionDetail(SessionRecord)
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var path = NavigationPath()
    @Published private(set) var hasAPIKey: Bool = (Keychain.loadAPIKey() ?? "").isEmpty == false

    @AppStorage("support.lowPressure") var lowPressure = false
    @AppStorage("support.readAloud") var readAloud = false
    @AppStorage("support.plainLanguage") var plainLanguage = false
    @AppStorage("support.showFillerMeter") var showFillerMeter = true

    let db = Database.shared
    lazy var auth = AuthStore(db: db)
    lazy var sessions = SessionStore(db: db)
    let claude = ClaudeClient()

    func setAPIKey(_ key: String) {
        Keychain.saveAPIKey(key)
        hasAPIKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func logout() {
        currentUser = nil
        path = NavigationPath()
    }

    func goHome() {
        path = NavigationPath()
    }
}
