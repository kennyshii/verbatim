import SwiftUI

struct OnlineSessionView: View {
    let code: String
    let playerId: String

    @EnvironmentObject private var app: AppState
    @AppStorage("support.readAloud") private var readAloud = false
    @AppStorage("support.showFillerMeter") private var showFillerMeter = true

    @State private var room: Room?
    @State private var input = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showEndConfirm = false
    @State private var aiInFlight = false
    @State private var judgingInFlight = false
    @State private var saved = false
    @State private var spokenAI: Set<String> = []

    private let client = RoomClient()

    private var isHost: Bool { room?.hostId == playerId }
    private var me: RoomPlayer? { room?.player(playerId) }
    private var myTurn: Bool { room?.expected?.type == "player" && room?.expected?.playerId == playerId }

    private var crossfirePrompt: (index: Int, total: Int, text: String)? {
        guard let room, myTurn, room.expected?.messageKind == .crossfireAnswer,
              let asked = room.speeches.last(where: { $0.messageKind == .crossfireQuestion })
        else { return nil }
        let list = ChatMessage.questions(in: asked.text)
        let answered = room.expected?.questionIndex ?? 0
        guard answered < list.count else { return nil }
        return (answered + 1, list.count, list[answered])
    }

    private var config: PracticeConfig? {
        guard let room, let me else { return nil }
        var c = PracticeConfig(kind: .debate, topic: room.topic,
                               language: Language(rawValue: room.language) ?? .english,
                               difficulty: Difficulty(rawValue: room.difficulty) ?? .medium,
                               mode: room.mode)
        c.userSide = Side(rawValue: me.side) ?? .affirmative
        c.judgePreset = JudgePreset(rawValue: room.judgePreset) ?? .novice
        c.judgeInstructions = room.judgeInstructions
        c.online = true
        c.participants = room.players.sorted { $0.slot < $1.slot }.map {
            Participant(name: $0.name, side: Side(rawValue: $0.side) ?? .affirmative, role: $0.role, isUser: $0.id == playerId)
        }
        return c
    }

    private var transcript: [ChatMessage] {
        guard let room else { return [] }
        return room.speeches.map { s in
            let mine = s.playerId == playerId || (room.mode == .team && s.playerId != nil)
            return ChatMessage(id: UUID(uuidString: s.id) ?? UUID(), role: mine ? .user : .assistant, text: s.text, speaker: s.speaker, statCheck: s.statCheck, kind: s.messageKind)
        }
    }

    var body: some View {
        Group {
            if let room {
                VStack(spacing: 0) {
                    header(room)
                    Divider()
                    switch room.status {
                    case "lobby": lobby(room)
                    case "live": live(room)
                    case "judging": judging(room)
                    default: result(room)
                    }
                }
            } else {
                ProgressView("Connecting to room \(code)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(room?.mode.rawValue ?? "Online round")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(room?.status == "live")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let room, room.status == "live", isHost {
                    Button("End Round") { showEndConfirm = true }
                } else if let room, room.status == "done" {
                    Button("Done") { Speaker.shared.stop(); app.goHome() }
                        .disabled(!saved && room.result != nil)
                } else if room?.status == "lobby" {
                    Button("Leave") { app.goHome() }
                }
            }
        }
        .confirmationDialog("End the round now?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Round") { endRound() }
            Button("Keep going", role: .cancel) {}
        }
        .task { await poll() }
        .onDisappear { Speaker.shared.stop() }
    }

    private func header(_ room: Room) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resolution").font(.caption).foregroundStyle(.secondary)
            Text(room.topic).font(.headline).foregroundStyle(Theme.accent)
            HStack(spacing: 8) {
                Label(room.code, systemImage: "number").font(.caption.weight(.semibold).monospaced())
                Text("· \(room.mode.rawValue) · \(room.difficulty) · \(room.language)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.tint)
    }

    private func lobby(_ room: Room) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room code").font(.caption).foregroundStyle(.secondary)
                    Text(room.code)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Text("Share this code. Others open the app, tap \"Join a round with a code\", and enter it with their name.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ShareLink(item: "Join my debate round in Debate Practice — code \(room.code). Resolution: \(room.topic)") {
                        Label("Share code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Debaters (\(room.players.count)/\(room.capacity))")
                    ForEach(room.players.sorted { $0.slot < $1.slot }) { p in
                        HStack {
                            Image(systemName: p.id == room.hostId ? "crown" : "person")
                                .foregroundStyle(Theme.accent)
                            Text(p.name).fontWeight(p.id == playerId ? .semibold : .regular)
                            Spacer()
                            Text("\(p.side) · \(p.role)").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .card()
                    }
                    ForEach(room.players.count..<max(room.players.count, room.capacity), id: \.self) { _ in
                        HStack {
                            Image(systemName: "person.badge.clock").foregroundStyle(.tertiary)
                            Text("Waiting for a debater to join…").foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .card()
                    }
                }

                if isHost {
                    Button {
                        Task { await setStatus("live") }
                    } label: {
                        Text(room.isFull ? "Start the round" : "Waiting for everyone…")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!room.isFull)
                } else {
                    Text("The host starts the round once everyone has joined.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .padding(20)
        }
    }

    private func live(_ room: Room) -> some View {
        VStack(spacing: 0) {
            turnBanner(room)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if room.speeches.isEmpty {
                            Text(room.mode == .team
                                 ? "The case speaker opens, the AI opposing team answers, then crossfire: the AI asks your team three questions you answer live, one at a time."
                                 : "The affirmative opens. Each debater speaks from their own phone when the banner says it's their turn.")
                                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 8)
                        }
                        ForEach(transcript) { message in
                            MessageBubble(message: message, mode: room.mode, language: config?.language ?? .english, showMetrics: showFillerMeter)
                        }
                        if aiInFlight {
                            Text(room.expected?.messageKind == .crossfireQuestion ? "Opposing team is preparing crossfire questions…" : "Opposing team is responding…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(12)
                }
                .onChange(of: room.speeches.count) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            Divider()
            VStack(spacing: 8) {
                if let cf = crossfirePrompt {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Crossfire question \(cf.index) of \(cf.total)", systemImage: "questionmark.bubble")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Text(cf.text).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .card(fill: Theme.tint)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(crossfirePrompt != nil ? "Answer live…" : myTurn ? "Your speech…" : "Waiting for your turn…", text: $input, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!myTurn)
                    Button("Send") { Task { await sendSpeech() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(!myTurn || isSending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if showFillerMeter && !input.isEmpty {
                    MeterBar(metrics: SpeechMetrics.analyze(input), compact: true)
                }
            }
            .padding(12)
            .background(Theme.surface)
        }
    }

    private func turnBanner(_ room: Room) -> some View {
        HStack(spacing: 6) {
            Image(systemName: myTurn ? "mic.fill" : "person.fill")
            if let cf = crossfirePrompt {
                Text("Crossfire — your turn, question \(cf.index) of \(cf.total)")
            } else if myTurn {
                Text("Your turn — \(me?.side ?? "") · \(me?.role ?? "")")
            } else if room.expected?.messageKind == .crossfireQuestion {
                Text("Opposing team is preparing crossfire questions…")
            } else if room.expected?.type == "ai" {
                Text("Opposing team is responding…")
            } else if let id = room.expected?.playerId, let p = room.player(id) {
                Text(room.expected?.messageKind == .crossfireAnswer
                     ? "Crossfire — \(p.name) is answering"
                     : "Now speaking: \(p.name) · \(p.side) · \(p.role)")
            } else {
                Text("Waiting…")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(myTurn ? Color.white : Theme.sandText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(myTurn ? Theme.accent : Theme.sand)
    }

    private func judging(_ room: Room) -> some View {
        VStack(spacing: 12) {
            ProgressView(room.mode.isJudged ? "The judge is deciding…" : "The coach is reviewing the round…")
            if isHost {
                Text("Your phone is running the judge with your API key.").font(.footnote).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                if isHost { Button("Retry") { Task { await runJudging() } }.buttonStyle(.bordered) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func result(_ room: Room) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let decision = room.result?.decision, let config {
                    JudgeDecisionView(decision: decision, affirmative: config.names(on: .affirmative), negative: config.names(on: .negative), language: config.language)
                } else if let feedback = room.result?.feedback, let config {
                    FeedbackSectionsView(feedback: feedback, kind: .debate, compact: false, language: config.language)
                } else {
                    Text("The round ended without a result.").foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Delivery")
                    ForEach(room.players.sorted { $0.slot < $1.slot }) { p in
                        MeterBar(metrics: SpeechMetrics.analyze(turns: room.speeches.filter { $0.playerId == p.id }.map(\.text)), title: "\(p.name) — presentational accuracy")
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if saved {
                    Text("Saved to your progress.").font(.footnote).foregroundStyle(.secondary)
                }

                Text("Transcript").font(.title3).bold().foregroundStyle(Theme.accent)
                ForEach(transcript) { message in
                    MessageBubble(message: message, mode: room.mode, language: config?.language ?? .english)
                }
            }
            .padding(20)
        }
        .onAppear(perform: saveLocally)
    }

    private func poll() async {
        while !Task.isCancelled {
            do {
                let latest = try await client.fetch(code: code)
                let changed = latest != room
                room = latest
                if changed { await reactToRoom(latest) }
            } catch {
                if room == nil { errorMessage = error.localizedDescription }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private func reactToRoom(_ room: Room) async {
        if readAloud, let last = room.speeches.last, last.playerId == nil, !spokenAI.contains(last.id) {
            spokenAI.insert(last.id)
            Speaker.shared.speak(last.text, language: config?.language ?? .english)
        }
        guard isHost else { return }
        if room.status == "live", room.mode == .team, room.expected?.type == "ai", !aiInFlight {
            if room.expected?.messageKind == .crossfireQuestion {
                await runCrossfire()
            } else {
                await runTeamAI(room)
            }
        }
        if room.status == "judging", !judgingInFlight, room.result == nil {
            await runJudging()
        }
    }

    private func sendSpeech() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let config else { return }
        isSending = true
        errorMessage = nil
        do {
            let updated = try await client.speak(code: code, playerId: playerId, text: text)
            input = ""
            room = updated
            if SpeechMetrics.containsStatistic(text), let speech = updated.speeches.last(where: { $0.playerId == playerId }), speech.messageKind == .speech {
                Task {
                    if let verdict = try? await app.claude.checkStatistics(in: text, topic: config.topic, language: config.language) {
                        room = try? await client.attachStatCheck(code: code, playerId: playerId, speechId: speech.id, statCheck: verdict)
                    }
                }
            }
            await reactToRoom(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    private func runTeamAI(_ room: Room) async {
        guard let config else { return }
        aiInFlight = true
        errorMessage = nil
        do {
            let reply = try await app.claude.liveTurn(config: config, history: transcript)
            self.room = try await client.aiSpeech(code: code, hostId: playerId, speaker: "Opposing team", text: reply)
        } catch {
            errorMessage = "AI turn failed: \(error.localizedDescription)"
        }
        aiInFlight = false
    }

    private func runCrossfire() async {
        guard let config else { return }
        aiInFlight = true
        errorMessage = nil
        do {
            let questions = try await app.claude.crossfireQuestions(config: config, history: transcript)
            let text = questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            room = try await client.aiSpeech(code: code, hostId: playerId, speaker: "Opposing team", text: text)
        } catch {
            errorMessage = "Crossfire failed: \(error.localizedDescription)"
        }
        aiInFlight = false
    }

    private func setStatus(_ status: String) async {
        errorMessage = nil
        do {
            room = try await client.setStatus(code: code, hostId: playerId, status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endRound() {
        guard let room else { return }
        let speakers = Set(room.speeches.compactMap(\.playerId))
        guard room.players.allSatisfy({ speakers.contains($0.id) }) else {
            errorMessage = "Every debater needs to speak at least once first."
            return
        }
        Task {
            await setStatus("judging")
            await runJudging()
        }
    }

    private func runJudging() async {
        guard isHost, let config, let room, !judgingInFlight else { return }
        judgingInFlight = true
        errorMessage = nil
        do {
            if room.mode.isJudged {
                let decision = try await app.claude.judgeRound(config: config, transcript: transcript, affirmative: config.names(on: .affirmative), negative: config.names(on: .negative))
                self.room = try await client.postResult(code: code, hostId: playerId, decision: decision, feedback: nil)
            } else {
                let feedback = try await app.claude.postSessionFeedback(config: config, transcript: transcript)
                self.room = try await client.postResult(code: code, hostId: playerId, decision: nil, feedback: feedback)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        judgingInFlight = false
    }

    private func saveLocally() {
        guard !saved, let room, let config, let user = app.currentUser else { return }
        let feedback: SessionFeedback?
        if let d = room.result?.decision { feedback = .judge(d) }
        else if let f = room.result?.feedback { feedback = .coach(f) }
        else { feedback = nil }
        guard let feedback else { return }
        do {
            try app.sessions.save(userId: user.id, config: config, transcript: transcript, feedback: feedback)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
