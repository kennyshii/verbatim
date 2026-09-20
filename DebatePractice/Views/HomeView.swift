import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState

    @State private var streak: Streak = .none
    @State private var sessionCount = 0
    @State private var accuracy: Int?
    @State private var showJoin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusCard

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Practice modes")
                    ForEach(SessionMode.options(for: .debate)) { mode in
                        Button {
                            app.push(.debateSetupMode(mode))
                        } label: {
                            ModeRow(mode: mode)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Suggested resolutions")
                    ForEach(suggestedResolutions, id: \.self) { resolution in
                        Button {
                            app.push(.debateSetup(resolution))
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "quote.opening")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 3)
                                Text(resolution)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.cream)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { showJoin = true } label: {
                    Label("Join a round with a code", systemImage: "number")
                }
                .buttonStyle(SecondaryButton())

                if !app.hasAPIKey {
                    Label("Add an Anthropic API key in Settings to start a round.", systemImage: "key")
                        .font(.footnote)
                        .foregroundStyle(Theme.sandText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(fill: Theme.sand)
                }
            }
            .padding(20)
            .padding(.bottom, 60)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandHeader(size: 26)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log out") { app.logout() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .sheet(isPresented: $showJoin) { JoinRoomSheet() }
        .onAppear(perform: load)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(streak.current > 0 ? Theme.success : Theme.secondaryText)
                    .frame(width: 8, height: 8)
                Text(streak.current > 0 ? "Streak active" : "No active streak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(streak.current > 0 ? Theme.success : Theme.secondaryText)
                Spacer()
                if let user = app.currentUser {
                    Text(user.username)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Text(streak.current > 0 ? "\(streak.current)-day streak" : "Ready to practice")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.cream)

            HStack(spacing: 0) {
                metric("Sessions", "\(sessionCount)")
                Divider().frame(height: 30).overlay(Theme.border)
                metric("Longest", "\(streak.longest)d")
                Divider().frame(height: 30).overlay(Theme.border)
                metric("Accuracy", accuracy.map { "\($0)%" } ?? "—")
            }

            Button {
                app.push(.debateSetup(nil))
            } label: {
                Text("Start a debate")
            }
            .buttonStyle(PrimaryButton())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.surface, radius: 22)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.cream)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() {
        guard let user = app.currentUser else { return }
        streak = (try? app.sessions.streak(for: user.id)) ?? .none
        let sessions = (try? app.sessions.sessions(for: user.id)) ?? []
        sessionCount = sessions.count
        var totals: [Int] = []
        for session in sessions {
            let metrics = SpeechMetrics.analyze(turns: session.ownTurns)
            if metrics.wordCount > 0 { totals.append(metrics.overall) }
        }
        accuracy = totals.isEmpty ? nil : totals.reduce(0, +) / totals.count
    }
}

struct ModeRow: View {
    let mode: SessionMode

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mode.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Theme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.rawValue)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.cream)
                Text(mode.explanation)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(Rectangle())
    }
}
