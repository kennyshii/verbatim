import Foundation

struct SessionStore {
    let db: Database

    private var encoder: JSONEncoder { JSONEncoder() }
    private var decoder: JSONDecoder { JSONDecoder() }

    @discardableResult
    func save(userId: Int64, config: PracticeConfig, transcript: [ChatMessage], feedback: SessionFeedback) throws -> Int64 {
        let transcriptJSON = String(decoding: try encoder.encode(transcript), as: UTF8.self)
        let feedbackJSON: String
        switch feedback {
        case .coach(let f): feedbackJSON = String(decoding: try encoder.encode(f), as: UTF8.self)
        case .judge(let j): feedbackJSON = String(decoding: try encoder.encode(j), as: UTF8.self)
        }
        let now = ISO8601DateFormatter().string(from: Date())

        let id = try db.insert(
            """
            INSERT INTO sessions (user_id, kind, topic, language, difficulty, mode, transcript, feedback, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [userId, config.kind.rawValue, config.topic, config.language.rawValue, config.difficulty.rawValue,
             config.mode.rawValue, transcriptJSON, feedbackJSON, now]
        )
        try updateStreak(userId: userId)
        return id
    }

    func sessions(for userId: Int64) throws -> [SessionRecord] {
        let rows = try db.query(
            "SELECT * FROM sessions WHERE user_id = ? ORDER BY id DESC",
            [userId]
        )
        return rows.compactMap { row in
            guard let id = row["id"] as? Int64 else { return nil }
            let transcript = (row["transcript"] as? String)
                .flatMap { try? decoder.decode([ChatMessage].self, from: Data($0.utf8)) } ?? []
            let feedback: SessionFeedback? = (row["feedback"] as? String).flatMap { json in
                let data = Data(json.utf8)
                if let f = try? decoder.decode(DebateFeedback.self, from: data) { return .coach(f) }
                if let j = try? decoder.decode(JudgeDecision.self, from: data) { return .judge(j) }
                return nil
            }
            return SessionRecord(
                id: id,
                userId: userId,
                kind: PracticeKind(rawValue: row["kind"] as? String ?? "") ?? .debate,
                topic: row["topic"] as? String ?? "",
                language: row["language"] as? String ?? "",
                difficulty: row["difficulty"] as? String ?? "",
                mode: row["mode"] as? String ?? "",
                transcript: transcript,
                feedback: feedback,
                createdAt: row["created_at"] as? String ?? ""
            )
        }
    }

    func streak(for userId: Int64) throws -> Streak {
        guard let row = try db.query("SELECT * FROM streaks WHERE user_id = ?", [userId]).first else {
            return .none
        }
        let stored = Streak(
            current: Int(row["current_streak"] as? Int64 ?? 0),
            longest: Int(row["longest_streak"] as? Int64 ?? 0),
            lastActiveDate: row["last_active_date"] as? String
        )
        let alive = stored.lastActiveDate == Self.dayString(Date())
            || stored.lastActiveDate == Self.dayString(Self.yesterday())
        return alive ? stored : Streak(current: 0, longest: stored.longest, lastActiveDate: stored.lastActiveDate)
    }

    func updateStreak(userId: Int64) throws {
        let today = Self.dayString(Date())
        let yesterday = Self.dayString(Self.yesterday())
        let existing = try streak(for: userId)

        var current = existing.current
        if existing.lastActiveDate == today {
            return
        } else if existing.lastActiveDate == yesterday {
            current += 1
        } else {
            current = 1
        }
        let longest = max(existing.longest, current)

        try db.exec(
            """
            INSERT INTO streaks (user_id, current_streak, longest_streak, last_active_date)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                current_streak = excluded.current_streak,
                longest_streak = excluded.longest_streak,
                last_active_date = excluded.last_active_date
            """,
            [userId, current, longest, today]
        )
    }

    func briefing(for committee: Committee) throws -> String? {
        try db.query("SELECT content FROM briefings WHERE committee = ?", [committee.id]).first?["content"] as? String
    }

    func saveBriefing(_ content: String, for committee: Committee) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try db.exec(
            """
            INSERT INTO briefings (committee, content, created_at) VALUES (?, ?, ?)
            ON CONFLICT(committee) DO UPDATE SET content = excluded.content, created_at = excluded.created_at
            """,
            [committee.id, content, now]
        )
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
}
