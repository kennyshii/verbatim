import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var app: AppState

    @State private var streak: Streak = .none
    @State private var sessions: [SessionRecord] = []
    @State private var tags: [FeedbackTag] = []

    private var averageAccuracy: Int? {
        var totals: [Int] = []
        for session in sessions {
            let metrics = SpeechMetrics.analyze(turns: session.ownTurns)
            if metrics.wordCount > 0 { totals.append(metrics.overall) }
        }
        guard !totals.isEmpty else { return nil }
        let sum = totals.reduce(0, +)
        return sum / totals.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    StatTile(value: "\(streak.current)", label: "Current streak", icon: "flame.fill")
                    StatTile(value: "\(streak.longest)", label: "Longest streak", icon: "trophy.fill")
                }
                HStack(spacing: 12) {
                    StatTile(value: "\(sessions.count)", label: "Sessions", icon: "checkmark.circle.fill")
                    StatTile(value: averageAccuracy.map { "\($0)%" } ?? "—", label: "Avg. accuracy", icon: "waveform")
                }
                Text("Streak counts consecutive days with at least one completed session. Presentational accuracy blends filler words (−5 each), smoothness, and tone.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Recurring feedback")
                    if sessions.count < 2 {
                        emptyCard("Complete at least two sessions to see patterns in your feedback.")
                    } else if tags.isEmpty {
                        emptyCard("No recurring themes yet.")
                    } else {
                        ForEach(tags) { tag in
                            HStack {
                                Text(tag.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.cream)
                                Spacer()
                                Text("flagged in \(tag.count) sessions")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Past sessions")
                    if sessions.isEmpty {
                        emptyCard("No sessions yet.")
                    } else {
                        ForEach(sessions) { session in
                            NavigationLink(value: Route.sessionDetail(session)) {
                                HStack(spacing: 14) {
                                    Image(systemName: session.kind.icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 38, height: 38)
                                        .background(Theme.accent.opacity(0.14))
                                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.topic)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.cream)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                        Text("\(session.createdDisplay) · \(session.mode) · \(SpeechMetrics.analyze(turns: session.ownTurns).overall)%")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
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
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .background(Theme.background)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: load)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }

    private func load() {
        guard let user = app.currentUser else { return }
        streak = (try? app.sessions.streak(for: user.id)) ?? .none
        sessions = (try? app.sessions.sessions(for: user.id)) ?? []
        tags = TagExtractor.recurring(in: sessions)
    }
}

struct SessionDetailView: View {
    let session: SessionRecord

    @EnvironmentObject private var app: AppState

    private var language: Language { Language(rawValue: session.language) ?? .english }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.kind.subjectLabel).font(.caption).foregroundStyle(.secondary)
                    Text(session.topic).font(.headline).foregroundStyle(Theme.accent)
                    Text("\(session.createdDisplay) · \(session.mode) · \(session.difficulty) · \(session.language)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(session.sessionMode.isJudged ? "Decision" : "Feedback").font(.title3).bold().foregroundStyle(Theme.accent)
                switch session.feedback {
                case .coach(let f):
                    FeedbackSectionsView(feedback: f, kind: session.kind, compact: false, language: language)
                case .judge(let decision):
                    JudgeDecisionView(decision: decision, affirmative: "Affirmative", negative: "Negative", language: language)
                case nil:
                    Text("No feedback was saved for this session.").foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Delivery")
                    MeterBar(metrics: SpeechMetrics.analyze(turns: session.ownTurns))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Text("Transcript").font(.title3).bold().foregroundStyle(Theme.accent)
                ForEach(session.transcript) { message in
                    MessageBubble(message: message, mode: session.sessionMode, language: language)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}
