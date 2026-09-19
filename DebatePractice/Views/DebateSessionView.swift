import SwiftUI

struct PracticeSessionView: View {
    let config: PracticeConfig

    @EnvironmentObject private var app: AppState
    @AppStorage("support.readAloud") private var readAloud = false
    @AppStorage("support.showFillerMeter") private var showFillerMeter = true

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var showEndConfirm = false
    @State private var ready = false
    @State private var remaining = 0
    @State private var timerRunning = false
    @State private var showInquiry = false
    @State private var inquiryText = ""
    @State private var inquiryPending = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var userName: String { app.currentUser?.username ?? "You" }

    private var teamStep: ScriptStep? {
        config.mode == .team ? RoundScript.teamStep(messages.count) : nil
    }

    private var congressIndex: Int {
        messages.filter { $0.effectiveKind == .speech || $0.effectiveKind == .amendment }.count
    }

    private var congressSegment: CongressSegment? {
        config.mode == .congress ? RoundScript.congressSegment(congressIndex) : nil
    }

    private var clockText: String {
        let value = max(0, remaining)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private var currentParticipant: Participant? {
        guard config.mode.isMultiplayer, !config.participants.isEmpty else { return nil }
        if let step = teamStep {
            if case .player(let slot) = step.slot { return config.participants[slot % config.participants.count] }
            return nil
        }
        return config.participants[messages.count % config.participants.count]
    }

    private var awaitingAI: Bool {
        if let segment = congressSegment { return segment.slot == .ai }
        return teamStep?.slot == .ai
    }

    private var crossfirePrompt: (index: Int, total: Int, text: String)? {
        guard let step = teamStep, step.kind == .crossfireAnswer,
              let asked = messages.last(where: { $0.effectiveKind == .crossfireQuestion })
        else { return nil }
        let list = ChatMessage.questions(in: asked.text)
        let answered = messages.filter { $0.effectiveKind == .crossfireAnswer }.count
        guard answered < list.count else { return nil }
        return (answered + 1, list.count, list[answered])
    }

    private var canSend: Bool {
        !isThinking && !awaitingAI && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCongressUserTurn: Bool {
        congressSegment.map { $0.slot != .ai } ?? false
    }

    private var endLabel: String {
        switch config.mode {
        case .briefing: return "Finish Briefing"
        case .versus, .twoVtwo, .team, .congress: return "End Round"
        default: return "End Debate"
        }
    }

    private var title: String {
        switch config.mode {
        case .debate: return "Debate"
        case .coach: return "Coach session"
        case .briefing: return "Briefing"
        case .versus: return "1v1"
        case .twoVtwo: return "2v2"
        case .team: return "Team vs AI"
        case .congress: return "Congress round"
        }
    }

    private var intro: String {
        switch config.mode {
        case .debate: return "Make your opening argument for the resolution. The AI will argue against you."
        case .coach: return "Make your argument. The coach will give you structured feedback on each turn."
        case .briefing: return "Write out your points for the resolution — rough is fine. You'll get back a sharpened version and a list of what changed. Revise and resend as many times as you like."
        case .versus: return "Pass the phone to whoever is speaking. The affirmative opens. When you're both done, end the round and the judge decides."
        case .twoVtwo: return "Public Forum order: first speakers alternate, then second speakers, then around again. Pass the phone to whoever the header names. End the round for the judge's decision."
        case .team: return "\(config.participants.first?.name ?? "The case speaker") opens with the case. The AI opposing team answers, then crossfire: it asks your team three questions, answered live one at a time, alternating between partners. Then the rebuttal speaker takes over."
        case .congress: return "Deliver your \(config.userSide == .affirmative ? "affirmative" : "negative") speech on the bill. An opposing member will refute you and ask one question — answer it in your next speech."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            pinnedHeader
            Divider()
            if config.lowPressure && !ready && !config.mode.isMultiplayer {
                groundingCard
            } else {
                transcript
                Divider()
                composer
            }
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if config.mode == .congress {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showInquiry = true } label: { Image(systemName: "hand.raised") }
                        .accessibilityLabel("Point of inquiry")
                        .disabled(isThinking || inquiryPending)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(endLabel) { endTapped() }
                    .disabled(isThinking)
            }
        }
        .sheet(isPresented: $showInquiry) {
            InquirySheet(text: $inquiryText, pending: inquiryPending) { question in
                askInquiry(question)
            }
        }
        .onReceive(ticker) { _ in
            guard timerRunning, isCongressUserTurn else { return }
            remaining -= 1
        }
        .onChange(of: congressIndex) { resetClock() }
        .confirmationDialog(config.isJudged ? "End the round and send it to the judge?" : "End this session and get your feedback?",
                            isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button(endLabel) { finish() }
            Button("Keep going", role: .cancel) {}
        }
        .task {
            resetClock()
            advanceIfAITurn()
        }
        .onDisappear { Speaker.shared.stop() }
    }

    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(config.kind == .congress ? config.committee : config.kind.subjectLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(config.topic)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            if let p = currentParticipant {
                HStack(spacing: 6) {
                    Image(systemName: crossfirePrompt == nil ? "person.fill" : "questionmark.bubble.fill")
                    if let cf = crossfirePrompt {
                        Text("Crossfire — \(p.name) answers question \(cf.index) of \(cf.total)")
                    } else {
                        Text("Now speaking: \(p.name) · \(p.side.rawValue) · \(p.role)")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.sandText)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Theme.sand)
                .clipShape(Capsule())
                .accessibilityAddTraits(.isHeader)
            } else if let segment = congressSegment {
                HStack(spacing: 6) {
                    Image(systemName: segment.slot == .ai ? "person.wave.2.fill" : "mic.fill")
                    Text(segment.slot == .ai
                         ? "AI member — \(segment.title) (\(segment.stance), \(segment.clock))"
                         : "You — \(segment.title) (\(segment.stance))")
                    if segment.slot != .ai {
                        Text(remaining <= 0 && timerRunning ? "over time" : clockText)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(remaining <= 0 && timerRunning ? Theme.danger : Theme.sandText)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.sandText)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Theme.sand)
                .clipShape(Capsule())
            } else {
                Text("\(config.mode.rawValue) · \(config.difficulty.rawValue) · \(config.language.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.tint)
    }

    private var groundingCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "heart")
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Text("Before you start")
                    .font(.title3.weight(.semibold))
                Text("Nobody is watching. Nothing here is graded. This is practice, and every round makes the next one easier.")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Breathe in for four counts, hold for four, out for four. Twice.", systemImage: "1.circle")
                    Label("Say your first point to yourself in one plain sentence.", systemImage: "2.circle")
                    Label("Remember you can take as long as you want between turns. There's no timer.", systemImage: "3.circle")
                }
                .font(.subheadline)
                Text("The opponent will stay calm and courteous and take one or two points at a time. You can end the session whenever you like.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    ready = true
                } label: {
                    Text("I'm ready")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(16)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        Text(intro)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message, mode: config.mode, language: config.language, showMetrics: showFillerMeter)
                    }

                    if isThinking {
                        Text("Thinking…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Theme.danger)
                            if !config.isJudged {
                                Button("Retry") { config.mode == .team || config.mode == .congress ? advanceIfAITurn() : requestReply() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: isThinking) { scrollToBottom(proxy) }
            .onChange(of: errorMessage) { scrollToBottom(proxy) }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let cf = crossfirePrompt {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Crossfire question \(cf.index) of \(cf.total)", systemImage: "questionmark.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(cf.text)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .card(fill: Theme.tint)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(crossfirePrompt != nil ? "Answer live…" : currentParticipant.map { "\($0.name)'s speech…" } ?? (config.mode == .briefing ? "Paste or type your draft…" : "Type your argument…"),
                          text: $input, axis: .vertical)
                    .lineLimit(1...(config.mode == .briefing ? 8 : 5))
                    .textFieldStyle(.roundedBorder)
                Button("Send") { send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend)
            }
            if showFillerMeter && !input.isEmpty {
                MeterBar(metrics: SpeechMetrics.analyze(input), compact: true)
            }
            if inquiryPending {
                Label("The parliamentarian is looking that up…", systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Theme.surface)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("bottom", anchor: .bottom)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        input = ""
        let message: ChatMessage
        if config.mode == .congress {
            let kind: MessageKind = RoundScript.congressIsAmendmentPhase(congressIndex) ? .amendment : .speech
            message = ChatMessage(role: .user, text: text, speaker: userName, kind: kind)
        } else if let p = currentParticipant {
            message = ChatMessage(role: p.isUser ? .user : .assistant, text: text, speaker: p.name, kind: teamStep?.kind ?? .speech)
        } else {
            message = ChatMessage(role: .user, text: text, speaker: userName, kind: .speech)
        }
        messages.append(message)
        if config.mode != .briefing && message.effectiveKind != .inquiry { runStatCheck(for: message) }
        if config.mode == .team || config.mode == .congress {
            timerRunning = false
            advanceIfAITurn()
        } else if !config.isJudged {
            requestReply()
        }
    }

    private func advanceIfAITurn() {
        if config.mode == .congress {
            guard !isThinking, congressSegment?.slot == .ai, !messages.isEmpty else { return }
            requestReply()
            return
        }
        guard config.mode == .team, !isThinking, let step = teamStep, step.slot == .ai else { return }
        if step.kind == .crossfireQuestion { requestCrossfire() } else { requestReply() }
    }

    private func resetClock() {
        guard let segment = congressSegment, segment.slot != .ai else {
            timerRunning = false
            return
        }
        remaining = segment.seconds
        timerRunning = true
    }

    private func askInquiry(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inquiryPending = true
        showInquiry = false
        inquiryText = ""
        messages.append(ChatMessage(role: .user, text: text, speaker: userName, kind: .inquiry))
        Task {
            do {
                let ruling = try await app.claude.pointOfInquiry(config: config, question: text, history: messages)
                messages.append(ChatMessage(role: .assistant, text: ruling, speaker: "Parliamentarian", kind: .ruling))
                if readAloud { Speaker.shared.speak(ruling, language: config.language) }
            } catch {
                errorMessage = error.localizedDescription
            }
            inquiryPending = false
        }
    }

    private func requestCrossfire() {
        errorMessage = nil
        isThinking = true
        Task {
            do {
                let questions = try await app.claude.crossfireQuestions(config: config, history: messages)
                let text = questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                messages.append(ChatMessage(role: .assistant, text: text, speaker: "Opposing team", kind: .crossfireQuestion))
                if readAloud { Speaker.shared.speak(text, language: config.language) }
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
        }
    }

    private func runStatCheck(for message: ChatMessage) {
        guard SpeechMetrics.containsStatistic(message.text) else { return }
        Task {
            guard let verdict = try? await app.claude.checkStatistics(in: message.text, topic: config.topic, language: config.language) else { return }
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].statCheck = verdict
            }
        }
    }

    private func requestReply() {
        errorMessage = nil
        isThinking = true
        Task {
            do {
                let reply = try await app.claude.liveTurn(config: config, history: messages)
                let speaker = config.mode == .team ? "Opposing team" : config.mode.assistantLabel
                let kind: MessageKind = config.mode == .congress && RoundScript.congressIsAmendmentPhase(congressIndex) ? .amendment : .speech
                messages.append(ChatMessage(role: .assistant, text: reply, speaker: speaker, kind: kind))
                if readAloud { Speaker.shared.speak(reply, language: config.language) }
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
            advanceIfAITurn()
        }
    }

    private func endTapped() {
        let enough: Bool
        if config.isJudged {
            let spoken = Set(messages.compactMap(\.speaker))
            enough = config.participants.allSatisfy { spoken.contains($0.name) }
        } else {
            enough = messages.contains { $0.role == .user }
        }
        if enough {
            showEndConfirm = true
        } else if messages.isEmpty {
            app.goHome()
        } else {
            errorMessage = config.isJudged ? "Every debater needs to speak at least once before the judge can decide." : "Say something first."
        }
    }

    private func finish() {
        Speaker.shared.stop()
        app.path.append(Route.feedback(config, messages))
    }
}

struct InquirySheet: View {
    @Binding var text: String
    var pending: Bool
    var onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Rise to a point of inquiry. A separate parliamentarian AI — not your opponent — will rule on it or look it up, then tell you where to verify the answer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("e.g. What is the current federal deficit? Or: is a motion to amend in order right now?", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(12)
                        .card()
                    Button {
                        onSubmit(text)
                    } label: {
                        Text("Rise to inquiry")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pending || text.trimmingCharacters(in: .whitespaces).isEmpty)
                    Text("Inquiries and rulings go into the record but are not scored as speeches.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Point of inquiry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let mode: SessionMode
    var language: Language = .english
    var showMetrics: Bool = false

    private var isUser: Bool { message.role == .user }

    private var label: String {
        if let speaker = message.speaker, mode.isMultiplayer { return speaker }
        return isUser ? "You" : mode.assistantLabel
    }

    private var isHumanSpeech: Bool {
        guard message.effectiveKind != .inquiry, message.effectiveKind != .ruling else { return false }
        return isUser || (mode.isJudged && message.role == .assistant)
    }

    private var isProcedural: Bool {
        message.effectiveKind == .inquiry || message.effectiveKind == .ruling
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.effectiveKind == .crossfireAnswer ? "\(label) · crossfire answer" : label)
                        .font(.caption)
                        .foregroundStyle(isUser ? Color.white.opacity(0.85) : Color.secondary)
                    Spacer()
                    if !isHumanSpeech {
                        ReadAloudButton(text: message.text, language: language)
                    }
                }

                if isProcedural {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(message.effectiveKind == .inquiry ? "Point of inquiry" : "The chair rules",
                              systemImage: message.effectiveKind == .inquiry ? "hand.raised" : "gavel")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(message.effectiveKind == .inquiry ? Color.white.opacity(0.9) : Theme.accent)
                        Text(message.text).textSelection(.enabled)
                    }
                } else if message.effectiveKind == .crossfireQuestion {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Crossfire", systemImage: "questionmark.bubble")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        ForEach(Array(ChatMessage.questions(in: message.text).enumerated()), id: \.offset) { index, question in
                            Text("\(index + 1). \(question)")
                                .font(.subheadline)
                        }
                    }
                } else if message.role == .assistant && mode == .coach {
                    FeedbackSectionsView(feedback: FeedbackParser.parse(message.text), kind: .debate, compact: true)
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }

                if showMetrics && isHumanSpeech {
                    let m = SpeechMetrics.analyze(message.text)
                    Text("\(m.overall)% · \(m.fillerCount) filler\(m.fillerCount == 1 ? "" : "s") · \(m.toneLabel.lowercased())")
                        .font(.caption2)
                        .foregroundStyle(isUser ? Color.white.opacity(0.8) : Color.secondary)
                }

                if let check = message.statCheck {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Stat check", systemImage: "checkmark.shield")
                            .font(.caption.weight(.semibold))
                        Text(check).font(.caption)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isUser ? Color.white.opacity(0.15) : Theme.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(10)
            .background(isUser ? Theme.accent : Theme.surface)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isUser ? Color.clear : Theme.border))

            if !isUser { Spacer(minLength: 40) }
        }
    }
}
