import Foundation

enum ClaudeError: LocalizedError {
    case missingKey
    case network(Error)
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No Anthropic API key set. Add one in Settings (gear icon on the Home screen)."
        case .network(let err):
            return "Network error: \(err.localizedDescription)"
        case .http(let code, let message):
            return "API error (\(code)): \(message)"
        case .badResponse:
            return "The API returned an unexpected response."
        }
    }
}

struct ClaudeClient {
    static let model = "claude-sonnet-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    static func debateSystemPrompt(_ c: PracticeConfig) -> String {
        var prompt = """
        You are a skilled, competitive debate opponent arguing the opposing side of the resolution: \(c.topic). Your goal is to win the argument, not to make the user feel good. Challenge weak points directly. Do not concede unless the user's argument is genuinely airtight. Do not use softening phrases like 'great point, but...' — go straight to your rebuttal. Do not praise the user during the debate. Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate — prefer logical reasoning and widely-known general knowledge over invented figures. Stay strictly on the topic: \(c.topic). Respond in \(c.language.rawValue). Match your argument complexity to difficulty level: \(c.difficulty.rawValue).
        """
        if c.lowPressure { prompt += lowPressureNote }
        return prompt
    }

    static func coachSystemPrompt(_ c: PracticeConfig) -> String {
        var prompt = """
        You are a debate coach reviewing a student's argument. Give specific, structured, constructive feedback — not encouragement for its own sake. Do not praise the user unless the praise is tied to a specific, identifiable strength you can quote from their text. Do not soften criticism with excessive hedging. Structure your response into exactly these four labeled sections: Strongest argument (with a quote), Weakest argument (with a quote), Missed rebuttal opportunity, Concrete suggestion for next time. Respond in \(c.language.rawValue).
        """
        if c.plainLanguage { prompt += plainLanguageNote }
        return prompt
    }

    static func briefingSystemPrompt(_ c: PracticeConfig) -> String {
        var prompt = """
        You are a debate coach helping a student sharpen a written brief in favor of the resolution: \(c.topic). The student sends drafts of their points. This is a text-to-text editing session, not a live exchange: do not argue the other side. For each draft, respond with exactly two labeled parts. "Sharpened version:" — a rewritten, tighter version that keeps the student's position, voice, and content but removes vagueness, filler, and weak logic, and makes each point land. "What changed and why:" — a short bulleted list naming the specific weaknesses you fixed and any gaps that still need real evidence or an example from the student. Be direct; no praise unless tied to something you can quote. Respond in \(c.language.rawValue). Match the depth of the rewrite to difficulty level: \(c.difficulty.rawValue).
        """
        if c.plainLanguage { prompt += plainLanguageNote }
        return prompt
    }

    static func teamSystemPrompt(_ c: PracticeConfig) -> String {
        let opposing = c.userSide.opposite
        var prompt = """
        You are the entire opposing team in a Public Forum style debate on the resolution: \(c.topic). The human team of two argues the \(c.userSide.rawValue.lowercased()); you argue the \(opposing.rawValue.lowercased()) and you play both of your team's speakers. Begin every speech with a line naming who is speaking: "First Speaker:" builds and extends your team's case and constructive arguments; "Second Speaker:" rebuts the human team's most recent arguments point by point. Your goal is to win the round. Challenge weak points directly, do not praise the human team, and do not concede unless an argument is genuinely airtight. Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate — prefer logical reasoning and widely known general knowledge. End every speech with a section headed "Crossfire:" containing exactly two pointed rhetorical questions the human team must answer, each exposing a gap or assumption in their case. Keep each speech under 220 words. Respond in \(c.language.rawValue). Match your complexity to difficulty level: \(c.difficulty.rawValue).
        """
        if c.lowPressure { prompt += lowPressureNote }
        return prompt
    }

    static func statCheckSystemPrompt(_ language: Language) -> String {
        """
        You are a careful fact-checker for a student debater. The student has just cited one or more numbers, statistics, or dollar figures in a practice speech. For each figure, give a one-line verdict — "Likely accurate", "Questionable", or "Can't verify" — followed by a short reason and the best source to confirm it (a specific agency, dataset, or report). Be honest about the limits of your knowledge and its cutoff date; never invent a corrected number unless you are highly confident. Keep the whole response under 120 words. Respond in \(language.rawValue).
        """
    }

    static func congressOpponentSystemPrompt(_ c: PracticeConfig, segment: CongressSegment) -> String {
        let billText = c.billText.isEmpty ? "" : "\n\nThe text of the legislation under debate:\n\"\"\"\n\(String(c.billText.prefix(6000)))\n\"\"\""
        var prompt = """
        You are a member of a model congress serving on the \(c.committee), debating the legislation: \(c.topic). The student is speaking in \(c.userSide == .affirmative ? "affirmation" : "negation") of the bill; you represent the opposing position and speak only against the student's side.\(billText)

        You are now delivering your \(segment.title.lowercased()), a \(segment.clock) speech in \(segment.stance.lowercased()) of the bill. Write roughly \(segment.wordBudget) words — the amount a speaker covers in \(segment.clock) at a normal speaking pace. Directly refute the student's most recent arguments before advancing your own, and end with exactly one pointed cross-examination question for the student. Maintain parliamentary decorum at all times; address the student as "the representative" or "the senator". Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate; prefer reasoning and widely known facts, and write "(verify)" after any figure you do use. Respond in \(c.language.rawValue). Match your rigor to difficulty level: \(c.difficulty.rawValue).
        """
        if c.lowPressure { prompt += lowPressureNote }
        return prompt
    }

    static func congressAmendmentSystemPrompt(_ c: PracticeConfig) -> String {
        let billText = c.billText.isEmpty ? "" : "\n\nThe text of the legislation:\n\"\"\"\n\(String(c.billText.prefix(6000)))\n\"\"\""
        var prompt = """
        You are a member of a model congress on the \(c.committee) who has been debating the legislation: \(c.topic), speaking against the student's position.\(billText)

        The main speeches are over and the floor is now open to amendments. Move exactly one amendment. Structure your turn with these labels, each on its own line: "Motion:" — the formal motion, phrased as "I move to amend the bill by…" naming the specific clause or section and the exact change. "Rationale:" — two or three sentences on why the amendment is necessary, tied to what the student argued. "Question to the sponsor:" — one pointed question the student must answer when they respond to the motion. Keep the whole turn under 200 words. Do not invent statistics; write "(verify)" after any figure. Respond in \(c.language.rawValue).
        """
        if c.lowPressure { prompt += lowPressureNote }
        return prompt
    }

    static func parliamentarianInquirySystemPrompt(_ c: PracticeConfig) -> String {
        """
        You are the presiding officer and parliamentarian of a model congress session on the \(c.committee), debating: \(c.topic). You are a neutral third party: you are not debating, you do not take a side, and you never argue for or against the bill. A member has risen to a point of inquiry and asked you to look something up or clarify a point of procedure.

        Answer in two labeled parts. "Ruling:" — a direct answer in two or three sentences. "Where to verify:" — the specific agency, dataset, or report the member should check, named precisely.

        Accuracy matters more than completeness. You have no live internet access and your knowledge has a cutoff date, so: state a figure only if you are highly confident, give it as an approximate value with its year and end it with "(verify)". If you are not confident, say plainly that you cannot confirm it from the chair and name exactly where the member should look. Never invent a number, a citation, or a rule. If the inquiry is procedural rather than factual, rule on it using standard parliamentary procedure. Respond in \(c.language.rawValue).
        """
    }

    static func statLookupSystemPrompt(_ language: Language) -> String {
        """
        You are a research assistant helping a student debater find a statistic they can use at the podium. Answer in three labeled parts, each on its own line. "Figure:" — the number itself, given as an approximate value with the year it comes from, ending with "(verify)". "Context:" — one or two sentences on what the number means and how a debater should and should not use it. "Source:" — the exact agency, dataset, or report that publishes it, named precisely enough to search for.

        Accuracy matters more than completeness. You have no live internet access and your knowledge has a cutoff date, so a figure that changes often — prices, counts that grow monthly, anything "right now" — should be given as the most recent value you are confident in, clearly labeled with its year, plus a warning that it has likely changed. If you are not confident of any figure, say so plainly under "Figure:" and put all your effort into naming exactly where the student can look it up. Never invent a number or a citation. Respond in \(language.rawValue).
        """
    }

    static func parliamentarianSystemPrompt(_ c: PracticeConfig) -> String {
        var prompt = """
        You are the parliamentarian and scoring judge for a Congressional Debate round in the \(c.committee) on the legislation: \(c.topic). Review the student's speeches and answers using standard Congressional Debate criteria: argumentation and clash, quality of evidence and reasoning, organization and clarity, responsiveness in questioning, and decorum. Give specific, structured, constructive feedback — not encouragement for its own sake. Do not praise the student unless the praise is tied to a specific, identifiable strength you can quote from their text. Do not soften criticism with excessive hedging. Structure your response into exactly these four labeled sections: Strongest argument (with a quote), Weakest argument (with a quote), Missed opportunity in refutation or questioning, Concrete suggestion for next time. Respond in \(c.language.rawValue).
        """
        if c.plainLanguage { prompt += plainLanguageNote }
        return prompt
    }

    static func judgeSystemPrompt(_ c: PracticeConfig, affirmative: String, negative: String) -> String {
        let paradigm = c.judgePreset == .custom ? c.judgeInstructions : c.judgePreset.instructions
        var prompt = """
        You are the judge of a debate on the resolution: \(c.topic). \(affirmative) argued the affirmative and \(negative) argued the negative. Judge paradigm and instructions: \(paradigm) Decide the round using only what was said in the transcript. Be specific: quote the debaters' own words when explaining what decided the round. Respond in \(c.language.rawValue).
        """
        if let sample = c.judgePreset.sampleRFD {
            prompt += """


            Here is a sample reason for decision written by a real judge in the style expected of you. Match its voice, its level of technical vocabulary, its specificity about which arguments were extended, dropped, or under-warranted, and its willingness to say plainly what did and did not persuade you. Do not copy its content, topic, or debaters — only its style and depth:
            \"\"\"
            \(sample)
            \"\"\"
            """
        }
        if c.plainLanguage { prompt += plainLanguageNote }
        return prompt
    }

    static func crossfireSystemPrompt(_ c: PracticeConfig) -> String {
        """
        You are the opposing team in a Public Forum style debate on the resolution: \(c.topic), arguing the \(c.userSide.opposite.rawValue.lowercased()). It is now crossfire. Ask the opposing team exactly three questions about the resolution and about the case they just presented. Each question must be a genuine cross-examination question that exposes a gap, an unwarranted assumption, or an unsupported number in their case — the kind a debater must answer on the spot. Number them 1., 2., and 3., one per line, with no preamble, no commentary, and nothing after the third question. Keep each question under 40 words. Respond in \(c.language.rawValue). Match your rigor to difficulty level: \(c.difficulty.rawValue).
        """
    }

    private static let lowPressureNote = "\n\nThe student has asked for a lower-pressure round. Keep every rule above, but stay calm and courteous, never mock or belittle, keep each response under 120 words, and take on one or two points at a time."

    private static let plainLanguageNote = "\n\nWrite in plain language: short sentences, everyday words, and define any debate jargon you use the first time it appears."

    private static func formatInstruction(_ c: PracticeConfig) -> String {
        let labels = DebateFeedback.sectionTitles(for: c.kind).map { "\"\($0):\"" }.joined(separator: ", ")
        return """
        Use exactly these four section labels, each on its own line and kept in English: \(labels). Write the content under each label in \(c.language.rawValue). Do not add any other headings, sections, or preamble.
        """
    }

    func liveTurn(config: PracticeConfig, history: [ChatMessage]) async throws -> String {
        switch config.mode {
        case .debate:
            return try await send(system: Self.debateSystemPrompt(config),
                                  messages: Self.apiMessages(from: history), maxTokens: 1024)
        case .coach:
            return try await coachTurnFeedback(config: config, history: history)
        case .briefing:
            return try await send(system: Self.briefingSystemPrompt(config),
                                  messages: Self.apiMessages(from: history), maxTokens: 1500)
        case .congress:
            let index = history.filter { $0.effectiveKind == .speech || $0.effectiveKind == .amendment }.count
            let segment = RoundScript.congressSegment(index)
            if RoundScript.congressIsAmendmentPhase(index) {
                return try await send(system: Self.congressAmendmentSystemPrompt(config),
                                      messages: Self.apiMessages(from: history), maxTokens: 700)
            }
            return try await send(system: Self.congressOpponentSystemPrompt(config, segment: segment),
                                  messages: Self.apiMessages(from: history), maxTokens: segment.seconds >= 240 ? 1400 : 800)
        case .team:
            var messages = Self.apiMessages(from: history)
            let aiTurns = history.filter { $0.role == .assistant }.count
            let role = aiTurns % 2 == 0 ? "First Speaker" : "Second Speaker"
            if var last = messages.last, last["role"] == "user" {
                last["content"] = (last["content"] ?? "") + "\n\n(Respond now as your \(role).)"
                messages[messages.count - 1] = last
            }
            return try await send(system: Self.teamSystemPrompt(config), messages: messages, maxTokens: 900)
        case .versus, .twoVtwo:
            throw ClaudeError.badResponse
        }
    }

    func crossfireQuestions(config: PracticeConfig, history: [ChatMessage]) async throws -> [String] {
        var prompt = "The human team argued the \(config.userSide.rawValue.lowercased()). Transcript so far:\n\n"
        for message in history {
            prompt += "\(message.speaker ?? (message.role == .user ? "Opposing team" : "You")): \(message.text)\n\n"
        }
        prompt += "Ask your three crossfire questions now."
        let raw = try await send(system: Self.crossfireSystemPrompt(config),
                                 messages: [["role": "user", "content": prompt]], maxTokens: 500)
        let questions = ChatMessage.questions(in: raw)
        guard questions.count == 3 else { throw ClaudeError.badResponse }
        return questions
    }

    func checkStatistics(in text: String, topic: String, language: Language) async throws -> String {
        let prompt = "Resolution or bill under debate: \(topic)\n\nThe student's speech:\n\"\"\"\n\(text)\n\"\"\"\n\nCheck every number, percentage, or dollar figure in it."
        return try await send(system: Self.statCheckSystemPrompt(language), messages: [["role": "user", "content": prompt]], maxTokens: 400)
    }

    private func coachTurnFeedback(config: PracticeConfig, history: [ChatMessage]) async throws -> String {
        let studentTurns = history.filter { $0.role == .user }.map(\.text)
        guard let latest = studentTurns.last else { throw ClaudeError.badResponse }
        let earlier = studentTurns.dropLast()

        var prompt = "Resolution: \"\(config.topic)\"\nThe student is arguing in favor of the resolution. Difficulty level: \(config.difficulty.rawValue).\n\n"
        if !earlier.isEmpty {
            prompt += "Earlier arguments from the student in this session (context only, do not review these):\n"
            for (i, text) in earlier.enumerated() { prompt += "\(i + 1). \(text)\n" }
            prompt += "\n"
        }
        prompt += "Latest argument to review:\n\"\"\"\n\(latest)\n\"\"\"\n\nReview only the latest argument. Quote the student's own words.\n\n"
        prompt += Self.formatInstruction(config)

        return try await send(system: Self.coachSystemPrompt(config),
                              messages: [["role": "user", "content": prompt]], maxTokens: 1024)
    }

    func postSessionFeedback(config: PracticeConfig, transcript: [ChatMessage]) async throws -> DebateFeedback {
        var prompt: String
        switch config.kind {
        case .debate:
            prompt = "Resolution: \"\(config.topic)\"\nMode: \(config.mode.rawValue). Difficulty: \(config.difficulty.rawValue).\nThe student argued in favor of the resolution."
        case .congress:
            prompt = "Committee: \(config.committee)\nLegislation: \(config.topic)\nThe student spoke in \(config.userSide == .affirmative ? "affirmation" : "negation") of the bill. Difficulty: \(config.difficulty.rawValue)."
        }
        if config.mode == .briefing {
            prompt += "\nThis was a written briefing session: the student's turns are drafts and the editor's turns are sharpened rewrites. Review only the student's own drafts."
        }
        if config.mode == .team {
            prompt += "\nThis was a two-person team round: \(config.names(on: config.userSide)) argued the \(config.userSide.rawValue.lowercased()) together against an AI opposing team. The round included a crossfire in which the opposing team asked three questions and the human team answered them live. Review the human team's speeches and their crossfire answers, noting specifically how directly and completely each question was answered."
        }
        prompt += "\nHere is the full transcript:\n\n"
        for message in transcript {
            let speaker: String
            switch message.effectiveKind {
            case .inquiry: speaker = "Student (point of inquiry)"
            case .ruling: speaker = "Parliamentarian (ruling, not part of the student's speeches)"
            case .amendment: speaker = message.role == .user ? "Student (on the amendment)" : "Opposing member (motion to amend)"
            default: speaker = message.role == .user ? (config.mode == .team ? (message.speaker ?? "Student") : "Student") : config.mode.assistantLabel
            }
            prompt += "\(speaker): \(message.text)\n\n"
        }
        prompt += "Review the student's performance across the whole session. Quote their own words when identifying the strongest and weakest parts.\n\n"
        prompt += Self.formatInstruction(config)

        let system = config.kind == .congress ? Self.parliamentarianSystemPrompt(config) : Self.coachSystemPrompt(config)
        let raw = try await send(system: system, messages: [["role": "user", "content": prompt]], maxTokens: 1500)
        return FeedbackParser.parse(raw)
    }

    func judgeRound(config: PracticeConfig, transcript: [ChatMessage], affirmative: String, negative: String) async throws -> JudgeDecision {
        var prompt = "Resolution: \"\(config.topic)\"\nAffirmative: \(affirmative)\nNegative: \(negative)\n\nTranscript, in speaking order:\n\n"
        for message in transcript {
            prompt += "\(message.speaker ?? "Speaker"): \(message.text)\n\n"
        }
        prompt += """
        Judge the round. Use exactly these four section labels, each on its own line and kept in English: "Decision:", "Reason for decision:", "Feedback for the Affirmative:", "Feedback for the Negative:". Under "Decision:" write only the winning side and the name(s) of who argued it. Write the content in \(config.language.rawValue). Do not add any other headings, sections, or preamble.
        """
        let raw = try await send(system: Self.judgeSystemPrompt(config, affirmative: affirmative, negative: negative),
                                 messages: [["role": "user", "content": prompt]], maxTokens: 1800)
        return FeedbackParser.parseDecision(raw, affirmative: affirmative, negative: negative)
    }

    func pointOfInquiry(config: PracticeConfig, question: String, history: [ChatMessage]) async throws -> String {
        var prompt = "Debate so far:\n\n"
        for message in history.suffix(6) {
            prompt += "\(message.speaker ?? (message.role == .user ? "The member" : "Opposing member")): \(message.text)\n\n"
        }
        prompt += "The member rises to a point of inquiry:\n\"\"\"\n\(question)\n\"\"\"\n\nRule on it."
        return try await send(system: Self.parliamentarianInquirySystemPrompt(config),
                              messages: [["role": "user", "content": prompt]], maxTokens: 600)
    }

    func lookUpStatistic(_ question: String, committee: Committee, language: Language) async throws -> String {
        let prompt = """
        The student is debating in the \(committee.fullName), whose jurisdiction is: \(committee.jurisdiction)
        The sources this committee relies on are: \(committee.sources.map(\.title).joined(separator: ", ")).

        Their question: "\(question)"
        """
        return try await send(system: Self.statLookupSystemPrompt(language),
                              messages: [["role": "user", "content": prompt]], maxTokens: 700)
    }

    private static func apiMessages(from history: [ChatMessage]) -> [[String: String]] {
        var result: [[String: String]] = []
        for message in history {
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if var last = result.last, last["role"] == message.role.rawValue {
                last["content"] = (last["content"] ?? "") + "\n\n" + text
                result[result.count - 1] = last
            } else {
                result.append(["role": message.role.rawValue, "content": text])
            }
        }
        if result.first?["role"] == "assistant" { result.removeFirst() }
        return result
    }

    private func send(system: String, messages: [[String: String]], maxTokens: Int) async throws -> String {
        guard let key = Keychain.loadAPIKey(), !key.isEmpty else { throw ClaudeError.missingKey }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw ClaudeError.badResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard http.statusCode == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw ClaudeError.http(http.statusCode, message)
        }

        guard let content = json?["content"] as? [[String: Any]] else { throw ClaudeError.badResponse }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ClaudeError.badResponse }
        return text
    }
}
