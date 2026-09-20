import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var app: AppState

    private enum Tab: String, CaseIterable { case login = "Log in", signup = "Sign up" }

    @State private var tab: Tab = .login
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            BrandHeader(size: 64)
            Text("Practice arguing. Get honest feedback.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 8)

            TextField("Username", text: $username)
                .field()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .field()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Theme.danger)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(tab.rawValue) { submit() }
                .buttonStyle(PrimaryButton())

            Spacer()
            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .onChange(of: tab) { errorMessage = nil }
    }

    private func submit() {
        do {
            let user: User
            switch tab {
            case .login: user = try app.auth.login(username: username, password: password)
            case .signup: user = try app.auth.signup(username: username, password: password)
            }
            errorMessage = nil
            password = ""
            app.currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
