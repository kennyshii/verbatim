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
    @State private var floorSpeaking = false

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

    private var congressOpenFloor: Bool {
        config.mode == .congress && RoundScript.congressIsOpenFloor(congressIndex)
    }

    private var congressUserTurn: Bool {
        if let segment = congressSegment { return config.userSpeaks(segment.stance) }
        return congressOpenFloor && floorSpeaking
    }

    private var activeSegment: CongressSegment? {
        congressSegment ?? (floorSpeaking ? RoundScript.floorSpeech : nil)
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
        if config.mode == .congress {
            if let segment = congressSegment { return !config.userSpeaks(segment.stance) }
            return false
        }
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

    private var showComposer: Bool {
        config.mode != .congress || congressUserTurn
    }

    private var canSend: Bool {
        !isThinking && !awaitingAI && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var endLabel: String {
        switch config.mode {
        case .versus, .twoVtwo, .team, .congress: return "End Round"
        default: return "End Debate"
        }
    }

    private var title: String {
        switch config.mode {
        case .debate: return "Debate"
        case .coach: return "Coach session"
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
        case .versus: return "Pass the phone to whoever is speaking. The affirmative opens. When you're both done, end the round and the judge decides."
        case .twoVtwo: return "Public Forum order: first speakers alternate, then second speakers, then around again. Pass the phone to whoever the header names. End the round for the judge's decision."
        case .team: return "\(config.participants.first?.name ?? "The case speaker") opens with the case. The AI opposing team answers, then crossfire: it asks your team three questions, answered live one at a time, alternating between partners. Then the rebuttal speaker takes over."
        case .congress:
            return config.userIsAuthor
                ? "You open with a two-minute authorship speech as the bill's sponsor. The AI member answers with a four-minute constructive against it, you give a two-minute second speech, and it closes with two more. Rise to a point of inquiry any time."
                : "The AI member is the bill's sponsor and opens with a two-minute authorship speech. You answer with a four-minute constructive against it, the sponsor gives a two-minute second speech, and you close with two more. Rise to a point of inquiry any time."
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
                if congressOpenFloor && !floorSpeaking {
                    floorChoice
                } else if showComposer {
                    composer
                }
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
        .confirmationDialog(config.isJudged ? "End the round and send it to the judge?" : "End this session and get your feedback?",
                            isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button(endLabel) { finish() }
            Button("Keep going", role: .cancel) {}
        }
        .sheet(isPresented: $showInquiry) {
            InquirySheet(text: $inquiryText, pending: inquiryPending) { question in
                askInquiry(question)
            }
        }
        .onReceive(ticker) { _ in
            guard timerRunning, congressUserTurn else { return }
            remaining -= 1
        }
        .onChange(of: congressIndex) { resetClock() }
        .task {
            resetClock()
            advanceIfAITurn()
        }
        .onDisappear { Speaker.shared.stop() }
    }

    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(config.kind == .congress ? config.committee : config.kind.subjectLabel)
                .subtext(.caption)
            Text(config.topic)
                .font(.brand(.headline, weight: .semibold))
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
                .font(.brand(.caption, weight: .semibold))
                .foregroundStyle(Theme.sandText)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Theme.sand)
                .clipShape(Capsule())
            } else if config.mode == .congress {
                congressBanner
            } else {
                Text("\(config.mode.rawValue) · \(config.difficulty.rawValue) · \(config.language.rawValue)")
                    .subtext(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.tint)
    }

    private var congressBanner: some View {
        HStack(spacing: 6) {
            if let segment = activeSegment {
                let mine = congressUserTurn
                Image(systemName: mine ? "mic.fill" : "person.wave.2.fill")
                Text(mine
                     ? "You — \(segment.title) (\(segment.stance.rawValue))"
                     : "AI member — \(segment.title) (\(segment.stance.rawValue), \(segment.clock))")
                if mine {
                    Text(remaining <= 0 && timerRunning ? "over time" : clockText)
                        .font(.brand(.caption, weight: .bold))
                        .foregroundStyle(remaining <= 0 && timerRunning ? Theme.danger : Theme.sandText)
                }
            } else {
                Image(systemName: "flag.checkered")
                Text("Main speeches complete — the floor is open")
            }
        }
        .font(.brand(.caption, weight: .semibold))
        .foregroundStyle(Theme.sandText)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Theme.sand)
        .clipShape(Capsule())
    }

    private var groundingCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "heart")
                    .font(.brand(.title, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("Before you start")
                    .font(.brand(.title3, weight: .semibold))
                Text("Nobody is watching. Nothing here is graded. This is practice, and every round makes the next one easier.")
                    .font(.brand(.subheadline))
                VStack(alignment: .leading, spacing: 8) {
                    Label("Breathe in for four counts, hold for four, out for four. Twice.", systemImage: "1.circle")
                    Label("Say your first point to yourself in one plain sentence.", systemImage: "2.circle")
                    Label("Remember you can take as long as you want between turns. There's no timer.", systemImage: "3.circle")
                }
                .font(.brand(.subheadline))
                Text("The opponent will stay calm and courteous and take one or two points at a time. You can end the session whenever you like.")
                    .subtext(.footnote)
                Button {
                    ready = true
                } label: {
                    Text("I'm ready")
                        .font(.brand(.headline, weight: .semibold))
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
                            .subtext(.subheadline)
                            .padding(.top, 8)
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message, mode: config.mode, language: config.language, showMetrics: showFillerMeter)
                    }

                    if isThinking {
                        Text("Thinking…")
                            .subtext(.subheadline)
                    }

                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(.brand(.footnote))
                                .foregroundStyle(Theme.danger)
                            if !config.isJudged {
                                Button("Retry") { advanceIfAITurn() }
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

    private var floorChoice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The main speeches are done. Take the floor again, or yield and let the other member move an amendment.")
                .subtext(.footnote)
            HStack(spacing: 10) {
                Button {
                    floorSpeaking = true
                    resetClock()
                } label: {
                    Label("Speak again (2:00)", systemImage: "mic")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    yieldFloor()
                } label: {
                    Label("Yield the floor", systemImage: "hand.wave")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(isThinking)
            }
        }
        .padding(12)
        .background(Theme.surface)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let cf = crossfirePrompt {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Crossfire question \(cf.index) of \(cf.total)", systemImage: "questionmark.bubble")
                        .font(.brand(.caption, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(cf.text)
                        .font(.brand(.subheadline))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .card(fill: Theme.tint)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(placeholder, text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .field()
                Button("Send") { send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend)
            }
            if showFillerMeter && !input.isEmpty {
                MeterBar(metrics: SpeechMetrics.analyze(input), compact: true)
            }
            if inquiryPending {
                Label("The parliamentarian is looking that up…", systemImage: "hand.raised")
                    .subtext(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Theme.surface)
    }

    private var placeholder: String {
        if crossfirePrompt != nil { return "Answer live…" }
        if let p = currentParticipant { return "\(p.name)'s speech…" }
        if let segment = activeSegment { return "\(segment.title)…" }
        return "Type your argument…"
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
            message = ChatMessage(role: .user, text: text, speaker: userName, kind: .speech)
        } else if let p = currentParticipant {
            message = ChatMessage(role: p.isUser ? .user : .assistant, text: text, speaker: p.name, kind: teamStep?.kind ?? .speech)
        } else {
            message = ChatMessage(role: .user, text: text, speaker: userName, kind: .speech)
        }
        messages.append(message)
        floorSpeaking = false
        if message.effectiveKind != .inquiry { runStatCheck(for: message) }
        if config.mode == .team || config.mode == .congress {
            timerRunning = false
            advanceIfAITurn()
        } else if !config.isJudged {
            requestReply()
        }
    }

    private func advanceIfAITurn() {
        if config.mode == .congress {
            guard !isThinking, let segment = congressSegment, !config.userSpeaks(segment.stance) else { return }
            requestReply()
            return
        }
        guard config.mode == .team, !isThinking, let step = teamStep, step.slot == .ai else { return }
        if step.kind == .crossfireQuestion { requestCrossfire() } else { requestReply() }
    }

    private func yieldFloor() {
        guard !isThinking else { return }
        floorSpeaking = false
        requestReply(kind: .amendment)
    }

    private func resetClock() {
        guard config.mode == .congress, let segment = activeSegment, congressUserTurn else {
            timerRunning = false
            return
        }
        remaining = segment.seconds
        timerRunning = true
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

    private func requestReply(kind: MessageKind = .speech) {
        errorMessage = nil
        isThinking = true
        Task {
            do {
                let reply = try await app.claude.liveTurn(config: config, history: messages)
                let speaker: String
                switch config.mode {
                case .team: speaker = "Opposing team"
                case .congress: speaker = config.userIsAuthor ? "Opposing member" : "Bill sponsor"
                default: speaker = config.mode.assistantLabel
                }
                messages.append(ChatMessage(role: .assistant, text: reply, speaker: speaker, kind: kind))
                if readAloud { Speaker.shared.speak(reply, language: config.language) }
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
            if config.mode == .congress { resetClock() }
            advanceIfAITurn()
        }
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

    private func endTapped() {
        let enough: Bool
        if config.isJudged {
            let spoken = Set(messages.compactMap(\.speaker))
            enough = config.participants.allSatisfy { spoken.contains($0.name) }
        } else {
            enough = messages.contains { $0.role == .user && $0.effectiveKind != .inquiry }
        }
        if enough {
            showEndConfirm = true
        } else if messages.isEmpty {
            app.goHome()
        } else {
            errorMessage = config.isJudged ? "Every debater needs to speak at least once before the judge can decide." : "Give at least one speech first."
        }
    }

    private func finish() {
        Speaker.shared.stop()
        app.push(.feedback(config, messages))
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
                        .subtext(.footnote)
                    TextField("e.g. What is the current federal deficit? Or: is a motion to amend in order right now?", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .field()
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
                        .subtext(.caption)
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
        if let speaker = message.speaker, mode.isMultiplayer || mode == .congress { return speaker }
        return isUser ? "You" : mode.assistantLabel
    }

    private var isProcedural: Bool {
        message.effectiveKind == .inquiry || message.effectiveKind == .ruling
    }

    private var isHumanSpeech: Bool {
        guard !isProcedural else { return false }
        return isUser || (mode.isJudged && message.role == .assistant)
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.effectiveKind == .crossfireAnswer ? "\(label) · crossfire answer" : label)
                        .font(.brand(.caption))
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
                            .font(.brand(.caption, weight: .semibold))
                            .foregroundStyle(isUser ? Color.white.opacity(0.9) : Theme.accent)
                        Text(message.text).textSelection(.enabled)
                    }
                } else if message.effectiveKind == .amendment {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Amendment", systemImage: "doc.badge.plus")
                            .font(.brand(.caption, weight: .semibold))
                            .foregroundStyle(isUser ? Color.white.opacity(0.9) : Theme.accent)
                        Text(message.text).textSelection(.enabled)
                    }
                } else if message.effectiveKind == .crossfireQuestion {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Crossfire", systemImage: "questionmark.bubble")
                            .font(.brand(.caption, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        ForEach(Array(ChatMessage.questions(in: message.text).enumerated()), id: \.offset) { index, question in
                            Text("\(index + 1). \(question)")
                                .font(.brand(.subheadline))
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
                        .font(.brand(.caption2))
                        .foregroundStyle(isUser ? Color.white.opacity(0.8) : Color.secondary)
                }

                if let check = message.statCheck {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Stat check", systemImage: "checkmark.shield")
                            .font(.brand(.caption, weight: .semibold))
                        Text(check).font(.brand(.caption))
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
