import Foundation

struct RoomPlayer: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let slot: Int
    let side: String
    let role: String
}

struct RoomSpeech: Codable, Hashable, Identifiable {
    let id: String
    let playerId: String?
    let speaker: String
    let side: String
    let role: String
    let text: String
    var kind: String?
    var statCheck: String?

    var messageKind: MessageKind {
        switch kind {
        case "crossfireQ": return .crossfireQuestion
        case "crossfireA": return .crossfireAnswer
        default: return .speech
        }
    }
}

struct RoomResult: Codable, Hashable {
    var decision: JudgeDecision?
    var feedback: DebateFeedback?
}

struct RoomExpected: Codable, Hashable {
    let type: String
    let playerId: String?
    var kind: String?
    var questionIndex: Int?

    var messageKind: MessageKind {
        switch kind {
        case "crossfireQ": return .crossfireQuestion
        case "crossfireA": return .crossfireAnswer
        default: return .speech
        }
    }
}

struct Room: Codable, Hashable {
    let code: String
    let format: String
    let topic: String
    let language: String
    let difficulty: String
    let judgePreset: String
    let judgeInstructions: String
    let hostId: String
    let hostSide: String
    let players: [RoomPlayer]
    let speeches: [RoomSpeech]
    let status: String
    let result: RoomResult?
    let capacity: Int
    let expected: RoomExpected?

    var mode: SessionMode { SessionMode(rawValue: format) ?? .versus }
    var isFull: Bool { players.count >= capacity }
    func player(_ id: String) -> RoomPlayer? { players.first { $0.id == id } }
}

enum RoomError: LocalizedError {
    case server(String)
    case badURL

    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .badURL: return "The relay server URL in Settings isn't valid."
        }
    }
}

struct RoomClient {
    static let serverKey = "room.serverURL"
    static let defaultServer = "http://localhost:8787"

    static var serverURL: String {
        let stored = UserDefaults.standard.string(forKey: serverKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultServer : stored
    }

    func create(config: PracticeConfig, hostName: String) async throws -> (Room, String) {
        let body: [String: Any] = [
            "format": config.mode.rawValue,
            "topic": config.topic,
            "language": config.language.rawValue,
            "difficulty": config.difficulty.rawValue,
            "judgePreset": config.judgePreset.rawValue,
            "judgeInstructions": config.judgeInstructions,
            "hostSide": config.userSide.rawValue,
            "hostName": hostName,
        ]
        let r: JoinResponse = try await request("rooms", body: body)
        return (r.room, r.playerId)
    }

    func join(code: String, name: String) async throws -> (Room, String) {
        let r: JoinResponse = try await request("rooms/\(code.uppercased())/join", body: ["name": name])
        return (r.room, r.playerId)
    }

    func fetch(code: String) async throws -> Room {
        let r: RoomResponse = try await request("rooms/\(code.uppercased())", body: nil)
        return r.room
    }

    func speak(code: String, playerId: String, text: String) async throws -> Room {
        let r: RoomResponse = try await request("rooms/\(code)/speeches", body: ["playerId": playerId, "text": text])
        return r.room
    }

    func attachStatCheck(code: String, playerId: String, speechId: String, statCheck: String) async throws -> Room {
        let r: RoomResponse = try await request("rooms/\(code)/statcheck", body: ["playerId": playerId, "speechId": speechId, "statCheck": statCheck])
        return r.room
    }

    func aiSpeech(code: String, hostId: String, speaker: String, text: String) async throws -> Room {
        let r: RoomResponse = try await request("rooms/\(code)/ai", body: ["playerId": hostId, "speaker": speaker, "text": text])
        return r.room
    }

    func setStatus(code: String, hostId: String, status: String) async throws -> Room {
        let r: RoomResponse = try await request("rooms/\(code)/status", body: ["playerId": hostId, "status": status])
        return r.room
    }

    func postResult(code: String, hostId: String, decision: JudgeDecision?, feedback: DebateFeedback?) async throws -> Room {
        var body: [String: Any] = ["playerId": hostId]
        let encoder = JSONEncoder()
        if let decision, let obj = try? JSONSerialization.jsonObject(with: encoder.encode(decision)) { body["decision"] = obj }
        if let feedback, let obj = try? JSONSerialization.jsonObject(with: encoder.encode(feedback)) { body["feedback"] = obj }
        let r: RoomResponse = try await request("rooms/\(code)/result", body: body)
        return r.room
    }

    private struct RoomResponse: Decodable { let room: Room }
    private struct JoinResponse: Decodable { let room: Room; let playerId: String }
    private struct ErrorResponse: Decodable { let error: String }

    private func request<T: Decodable>(_ path: String, body: [String: Any]?) async throws -> T {
        guard let base = URL(string: Self.serverURL), let url = URL(string: path, relativeTo: base.appendingPathComponent("")) else { throw RoomError.badURL }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        if let body {
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error ?? "Relay server error (\(status))"
            throw RoomError.server(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
