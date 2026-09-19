import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("support.lowPressure") private var lowPressure = false

    @State private var streak: Streak = .none
    @State private var showSettings = false
    @State private var showJoin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = app.currentUser {
                    Text("Hi, \(user.username)")
                        .font(.title2)
                        .bold()
                }

                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                    Text(streakLine)
                        .font(.headline)
                }
                .foregroundStyle(Theme.sandText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: Theme.sand)

                Button {
                    app.path.append(Route.debateSetup(nil))
                } label: {
                    BigCard(icon: "bubble.left.and.bubble.right.fill", title: "Debate Practice",
                            subtitle: "Lincoln-Douglas and Public Forum topics. Solo, coached, 1v1, 2v2, or team up against the AI.")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Suggested resolutions")
                    ForEach(suggestedResolutions, id: \.self) { resolution in
                        Button {
                            app.path.append(Route.debateSetup(resolution))
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "quote.opening")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 3)
                                Text(resolution)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showJoin = true
                } label: {
                    Label("Join a round with a code", systemImage: "number")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                Button {
                    app.path.append(Route.congress)
                } label: {
                    BigCard(icon: "building.columns.fill", title: "Model Congress",
                            subtitle: "Every House and Senate committee, with briefings and practice legislation.")
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.dashboard) {
                    Text("View Progress Dashboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                if lowPressure {
                    Label("Low-pressure mode is on", systemImage: "heart")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !app.hasAPIKey {
                    Text("No Anthropic API key set yet. Tap the gear icon to add one before starting a session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Log out") { app.logout() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showJoin) {
            JoinRoomSheet()
        }
        .onAppear(perform: loadStreak)
    }

    private var streakLine: String {
        streak.current > 0
            ? "\(streak.current)-day streak"
            : "No streak yet — complete a session today to start one."
    }

    private func loadStreak() {
        guard let user = app.currentUser else { return }
        streak = (try? app.sessions.streak(for: user.id)) ?? .none
    }
}

struct BigCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var muted: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(muted ? Color.secondary : Color.white)
                .frame(width: 48, height: 48)
                .background(muted ? Theme.tint : Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(muted ? Color.secondary : Color.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(Rectangle())
    }
}
