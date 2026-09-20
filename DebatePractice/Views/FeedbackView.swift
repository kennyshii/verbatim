import SwiftUI

struct FeedbackView: View {
    let config: PracticeConfig
    let transcript: [ChatMessage]

    @EnvironmentObject private var app: AppState
    @AppStorage("support.readAloud") private var readAloud = false

    @State private var feedback: SessionFeedback?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var saved = false

    private var userName: String { app.currentUser?.username ?? "You" }
    private var affirmativeName: String { config.names(on: .affirmative) }
    private var negativeName: String { config.names(on: .negative) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.kind == .congress ? config.committee : config.kind.subjectLabel).font(.brand(.caption)).foregroundStyle(Theme.secondaryText)
                    Text(config.topic).font(.brand(.headline, weight: .semibold)).foregroundStyle(Theme.accent)
                    Text("\(config.mode.rawValue) · \(config.difficulty.rawValue) · \(config.language.rawValue)")
                        .subtext(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if isLoading {
                    ProgressView(config.isJudged ? "The judge is deciding…" : "Generating feedback…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage).foregroundStyle(Theme.danger)
                        Button("Retry") { Task { await generate() } }
                            .buttonStyle(.bordered)
                    }
                } else if let feedback {
                    switch feedback {
                    case .coach(let f):
                        FeedbackSectionsView(feedback: f, kind: config.kind, compact: false)
                    case .judge(let decision):
                        JudgeDecisionView(decision: decision, affirmative: affirmativeName, negative: negativeName, language: config.language)
                    }

                    deliverySection

                    if saved {
                        Text("Saved to your progress.")
                            .subtext(.footnote)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(config.isJudged ? "Decision" : "Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { Speaker.shared.stop(); app.goHome() }
                    .disabled(isLoading)
            }
        }
        .task { await generate() }
    }

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Delivery")
            if config.mode.isMultiplayer {
                ForEach(config.participants, id: \.name) { p in
                    MeterBar(metrics: SpeechMetrics.analyze(turns: transcript.filter { $0.speaker == p.name }.map(\.text)), title: "\(p.name) — presentational accuracy")
                }
            } else {
                MeterBar(metrics: SpeechMetrics.analyze(turns: transcript.filter { $0.role == .user }.map(\.text)))
            }
            Text("Filler words cost 5 points each. Smoothness looks at run-ons, fragments, and stumbles; tone looks for hedging or an overheated voice. Aim for 90 or higher.")
                .subtext(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func generate() async {
        guard !saved else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result: SessionFeedback
            if config.isJudged {
                let decision = try await app.claude.judgeRound(config: config, transcript: transcript, affirmative: affirmativeName, negative: negativeName)
                result = .judge(decision)
                if readAloud { Speaker.shared.speak("Decision: \(decision.winner). \(decision.reasonForDecision)", language: config.language) }
            } else {
                let f = try await app.claude.postSessionFeedback(config: config, transcript: transcript)
                result = .coach(f)
                if readAloud {
                    let titles = DebateFeedback.sectionTitles(for: config.kind)
                    Speaker.shared.speak("\(titles[0]). \(f.strongestArgument). \(titles[1]). \(f.weakestArgument). \(titles[2]). \(f.missedRebuttal). \(titles[3]). \(f.suggestion)", language: config.language)
                }
            }
            feedback = result
            if let user = app.currentUser {
                try app.sessions.save(userId: user.id, config: config, transcript: transcript, feedback: result)
                saved = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FeedbackSectionsView: View {
    let feedback: DebateFeedback
    var kind: PracticeKind = .debate
    var compact: Bool
    var language: Language = .english

    private var sections: [(String, String)] {
        let titles = DebateFeedback.sectionTitles(for: kind)
        return [
            (titles[0], feedback.strongestArgument),
            (titles[1], feedback.weakestArgument),
            (titles[2], feedback.missedRebuttal),
            (titles[3], feedback.suggestion),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            ForEach(sections, id: \.0) { title, body in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(compact ? .brand(.subheadline, weight: .bold) : .brand(.headline, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        if !compact {
                            Spacer()
                            ReadAloudButton(text: "\(title). \(body)", language: language)
                        }
                    }
                    Text(body)
                        .font(compact ? .brand(.subheadline) : .brand(.body))
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(compact ? 0 : 12)
                .background(compact ? Color.clear : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    compact ? nil : RoundedRectangle(cornerRadius: 10).stroke(Theme.border)
                )
            }
        }
    }
}

struct JudgeDecisionView: View {
    let decision: JudgeDecision
    let affirmative: String
    let negative: String
    var language: Language = .english

    private var sections: [(String, String)] {
        [
            ("Reason for decision", decision.reasonForDecision),
            ("Feedback for \(affirmative) (Affirmative)", decision.affirmativeFeedback),
            ("Feedback for \(negative) (Negative)", decision.negativeFeedback),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Decision", systemImage: "rosette")
                        .font(.brand(.headline, weight: .semibold))
                        .foregroundStyle(Theme.sandText)
                    Spacer()
                    ReadAloudButton(text: "Decision: \(decision.winner). \(decision.reasonForDecision)", language: language)
                }
                Text(decision.winner)
                    .font(.brand(.title2, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .card(fill: Theme.sand)

            ForEach(sections, id: \.0) { title, body in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.brand(.headline, weight: .semibold)).foregroundStyle(Theme.accent)
                        Spacer()
                        ReadAloudButton(text: "\(title). \(body)", language: language)
                    }
                    Text(body).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .card()
            }
        }
    }
}
