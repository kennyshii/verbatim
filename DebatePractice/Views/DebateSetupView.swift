import SwiftUI

struct DebateSetupView: View {
    var initialTopic: String? = nil

    @EnvironmentObject private var app: AppState
    @AppStorage("support.lowPressure") private var lowPressure = false
    @AppStorage("support.plainLanguage") private var plainLanguage = false
    @AppStorage("prefs.language") private var languageRaw = Language.english.rawValue

    @State private var category: TopicCategory = topicCategories[0]
    @State private var useCustomTopic = false
    @State private var topicChoice: String = topicCategories[0].topics[0].text
    @State private var customTopic = ""
    @State private var difficulty: Difficulty = .medium
    @State private var mode: SessionMode = .debate
    @State private var showSettings = false
    @FocusState private var customFocused: Bool

    @State private var online = false
    @State private var userSide: Side = .affirmative
    @State private var displayName = ""
    @State private var partnerName = ""
    @State private var opponentName = ""
    @State private var opponent2Name = ""
    @State private var userRoleIsCase = true
    @State private var judgePreset: JudgePreset = .novice
    @State private var customJudge = ""
    @State private var isCreating = false
    @State private var createError: String?

    private var resolvedTopic: String {
        useCustomTopic ? customTopic.trimmingCharacters(in: .whitespacesAndNewlines) : topicChoice
    }

    private var canStart: Bool {
        guard !resolvedTopic.isEmpty, !isCreating else { return false }
        if mode.isJudged && judgePreset == .custom && customJudge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if mode.isMultiplayer {
            if online { return !displayName.trimmingCharacters(in: .whitespaces).isEmpty }
            switch mode {
            case .versus: return !opponentName.trimmingCharacters(in: .whitespaces).isEmpty
            case .twoVtwo: return ![partnerName, opponentName, opponent2Name].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            case .team: return !partnerName.trimmingCharacters(in: .whitespaces).isEmpty
            default: return true
            }
        }
        return true
    }

    private var startLabel: String {
        switch mode {
        case .versus, .twoVtwo, .team: return online ? "Create room & get code" : "Start \(mode.rawValue)"
        default: return "Start Debate"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topicSection
                modeSection
                if mode.isMultiplayer { connectionSection }
                if mode.isMultiplayer { sidesSection }
                if mode.isJudged { judgeSection }
                ChoiceSections(difficulty: $difficulty)

                if let createError {
                    Text(createError).font(.footnote).foregroundStyle(Theme.danger)
                }

                Button {
                    start()
                } label: {
                    Text(isCreating ? "Creating room…" : startLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Set up your debate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SettingsView(message: "Add an Anthropic API key to start a debate.")
        }
        .onAppear(perform: applyInitialTopic)
    }

    private func applyInitialTopic() {
        if displayName.isEmpty { displayName = app.currentUser?.username ?? "" }
        guard let initialTopic, topicChoice != initialTopic, customTopic != initialTopic else { return }
        if let cat = topicCategories.first(where: { $0.topics.contains { $0.text == initialTopic } }) {
            category = cat
            useCustomTopic = false
            topicChoice = initialTopic
        } else {
            useCustomTopic = true
            customTopic = initialTopic
        }
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Resolution")
            Text(mode.isMultiplayer ? "Pick sides below." : "You argue for it. In Debate mode the AI argues against.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topicCategories) { cat in
                        Chip(label: cat.name, icon: cat.icon, selected: !useCustomTopic && category.id == cat.id) {
                            category = cat
                            useCustomTopic = false
                            customFocused = false
                            if !cat.topics.contains(where: { $0.text == topicChoice }) { topicChoice = cat.topics[0].text }
                        }
                    }
                    Chip(label: "Custom", icon: "pencil", selected: useCustomTopic) {
                        useCustomTopic = true
                        customFocused = true
                    }
                }
                .padding(.vertical, 2)
            }

            if useCustomTopic {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write your own resolution")
                        .font(.subheadline.weight(.semibold))
                    TextField("e.g. Resolved: Cities should ban cars downtown.", text: $customTopic, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($customFocused)
                        .padding(12)
                        .card()
                    Text("Phrase it as a claim you can argue for, not a question.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(category.topics) { topic in
                    OptionCard(title: topic.text, subtitle: topic.period, selected: topicChoice == topic.text) {
                        topicChoice = topic.text
                    }
                }
                if let source = category.source {
                    Text("Topics from the National Speech & Debate Association: \(source)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Mode")
            ForEach(SessionMode.options(for: .debate)) { m in
                OptionCard(title: m.rawValue, subtitle: m.explanation, icon: m.icon, selected: mode == m) {
                    mode = m
                }
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "How are you playing?")
            HStack(spacing: 8) {
                Chip(label: "Same phone", icon: "iphone", selected: !online) { online = false }
                Chip(label: "Online with a code", icon: "wifi", selected: online) { online = true }
            }
            if online {
                Text("You'll get a six-character code to share. The other \(mode.humanCount - 1 == 1 ? "debater joins" : "\(mode.humanCount - 1) debaters join") from their own phones with \"Join a round with a code\" — no account needed. Uses the relay server set in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Your display name", text: $displayName)
                    .padding(12)
                    .card()
            } else {
                Text("Pass this phone around. Each debater types their speech when the header says it's their turn.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                switch mode {
                case .versus:
                    TextField("Opponent's name", text: $opponentName).padding(12).card()
                case .twoVtwo:
                    TextField("Your partner's name (second speaker on your side)", text: $partnerName).padding(12).card()
                    TextField("Opponent 1 (their first speaker)", text: $opponentName).padding(12).card()
                    TextField("Opponent 2 (their second speaker)", text: $opponent2Name).padding(12).card()
                case .team:
                    TextField("Your partner's name", text: $partnerName).padding(12).card()
                default:
                    EmptyView()
                }
            }
            if mode == .team {
                SectionLabel(text: "Your role").padding(.top, 6)
                HStack(spacing: 8) {
                    Chip(label: "I present the case", icon: "doc.text", selected: userRoleIsCase) { userRoleIsCase = true }
                    Chip(label: "I rebut", icon: "arrow.uturn.left", selected: !userRoleIsCase) { userRoleIsCase = false }
                }
                Text(online ? "The first person to join takes the other role." : "\(partnerName.isEmpty ? "Your partner" : partnerName) takes the other role. The case speaker opens; the AI answers every speech and asks crossfire questions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sidesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: mode == .team ? "Your team's side" : "Your side")
            HStack(spacing: 8) {
                ForEach(Side.allCases) { side in
                    Chip(label: "\(mode == .team ? "We're" : "I'm") \(side.rawValue)", selected: userSide == side) { userSide = side }
                }
            }
            Text(mode == .team
                 ? "The AI argues the \(userSide.opposite.rawValue.lowercased()) as both of its speakers."
                 : mode == .twoVtwo
                    ? "Speaking order: first speakers alternate, then second speakers. \(userSide == .affirmative ? "Your team" : "The other team") opens."
                    : "The affirmative speaks first.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var judgeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Judge")
            HStack(spacing: 8) {
                ForEach(JudgePreset.allCases) { preset in
                    Chip(label: preset.rawValue, icon: preset == .novice ? "leaf" : preset == .varsity ? "bolt" : "pencil",
                         selected: judgePreset == preset) { judgePreset = preset }
                }
            }
            if judgePreset == .custom {
                TextField("Write the judge's paradigm and instructions…", text: $customJudge, axis: .vertical)
                    .lineLimit(4...10)
                    .padding(12)
                    .card()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(judgePreset.rawValue) judge instructions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(judgePreset.instructions)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if judgePreset.sampleRFD != nil {
                        DisclosureGroup("Sample reason for decision in this style") {
                            Text(judgePreset.sampleRFD ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                        .font(.caption.weight(.semibold))
                        .tint(Theme.accent)
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: Theme.tint)
            }
        }
    }

    private func buildParticipants() -> [Participant] {
        let me = app.currentUser?.username ?? "You"
        let opp = userSide.opposite
        switch mode {
        case .versus:
            let user = Participant(name: me, side: userSide, role: "Debater", isUser: true)
            let other = Participant(name: opponentName.trimmingCharacters(in: .whitespaces), side: opp, role: "Debater", isUser: false)
            return userSide == .affirmative ? [user, other] : [other, user]
        case .twoVtwo:
            let user = Participant(name: me, side: userSide, role: "First speaker", isUser: true)
            let partner = Participant(name: partnerName.trimmingCharacters(in: .whitespaces), side: userSide, role: "Second speaker", isUser: false)
            let o1 = Participant(name: opponentName.trimmingCharacters(in: .whitespaces), side: opp, role: "First speaker", isUser: false)
            let o2 = Participant(name: opponent2Name.trimmingCharacters(in: .whitespaces), side: opp, role: "Second speaker", isUser: false)
            return userSide == .affirmative ? [user, o1, partner, o2] : [o1, user, o2, partner]
        case .team:
            let user = Participant(name: me, side: userSide, role: userRoleIsCase ? "Case" : "Rebuttal", isUser: true)
            let partner = Participant(name: partnerName.trimmingCharacters(in: .whitespaces), side: userSide, role: userRoleIsCase ? "Rebuttal" : "Case", isUser: true)
            return userRoleIsCase ? [user, partner] : [partner, user]
        default:
            return []
        }
    }

    private func start() {
        guard canStart else { return }
        guard app.hasAPIKey else {
            showSettings = true
            return
        }
        var config = PracticeConfig(kind: .debate, topic: resolvedTopic, language: Language(rawValue: languageRaw) ?? .english, difficulty: difficulty, mode: mode)
        config.lowPressure = lowPressure
        config.plainLanguage = plainLanguage
        config.userSide = userSide
        if mode.isJudged {
            config.judgePreset = judgePreset
            config.judgeInstructions = judgePreset == .custom ? customJudge.trimmingCharacters(in: .whitespacesAndNewlines) : judgePreset.instructions
        }
        if mode.isMultiplayer && online {
            config.online = true
            createRoom(config)
            return
        }
        config.participants = buildParticipants()
        app.path.append(Route.session(config))
    }

    private func createRoom(_ config: PracticeConfig) {
        isCreating = true
        createError = nil
        Task {
            do {
                let (room, playerId) = try await RoomClient().create(config: config, hostName: displayName.trimmingCharacters(in: .whitespaces))
                app.path.append(Route.onlineSession(room.code, playerId))
            } catch {
                createError = error.localizedDescription
            }
            isCreating = false
        }
    }
}

struct ChoiceSections: View {
    @Binding var difficulty: Difficulty

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Difficulty")
            HStack(spacing: 8) {
                ForEach(Difficulty.allCases) { level in
                    Chip(label: level.rawValue, icon: level.icon, selected: difficulty == level) { difficulty = level }
                }
            }
            Text(difficulty.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
