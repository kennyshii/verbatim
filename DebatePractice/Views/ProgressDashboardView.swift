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
        List {
            Section {
                HStack(spacing: 10) {
                    StatTile(value: "\(streak.current)", label: "Current streak", icon: "flame.fill")
                    StatTile(value: "\(streak.longest)", label: "Longest streak", icon: "trophy.fill")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                HStack(spacing: 10) {
                    StatTile(value: "\(sessions.count)", label: "Sessions", icon: "checkmark.circle.fill")
                    StatTile(value: averageAccuracy.map { "\($0)%" } ?? "—", label: "Avg. presentational accuracy", icon: "waveform")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                Text("Streak counts consecutive days with at least one completed session. Presentational accuracy blends filler words (−5 each), smoothness, and tone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Recurring feedback") {
                if sessions.count < 2 {
                    Text("Complete at least two sessions to see patterns in your feedback.")
                        .foregroundStyle(.secondary)
                } else if tags.isEmpty {
                    Text("No recurring themes yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tags) { tag in
                        LabeledContent(tag.name, value: "flagged in \(tag.count) sessions")
                    }
                }
            }

            Section("Past sessions") {
                if sessions.isEmpty {
                    Text("No sessions yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(value: Route.sessionDetail(session)) {
                            HStack(spacing: 12) {
                                Image(systemName: session.kind.icon)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.topic).font(.body).lineLimit(2)
                                    Text("\(session.createdDisplay) · \(session.mode) · \(session.difficulty) · \(session.language) · \(SpeechMetrics.analyze(turns: session.ownTurns).percent)%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
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
