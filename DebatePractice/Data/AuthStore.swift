import Foundation
import CommonCrypto
import Security

enum AuthError: LocalizedError {
    case emptyFields
    case usernameTaken
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .emptyFields: return "Enter a username and password."
        case .usernameTaken: return "That username is already taken."
        case .invalidCredentials: return "Incorrect username or password."
        }
    }
}

struct AuthStore {
    let db: Database

    func signup(username: String, password: String) throws -> User {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !password.isEmpty else { throw AuthError.emptyFields }

        let existing = try db.query("SELECT id FROM users WHERE username = ?", [name])
        guard existing.isEmpty else { throw AuthError.usernameTaken }

        let now = ISO8601DateFormatter().string(from: Date())
        let id = try db.insert(
            "INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)",
            [name, PasswordHasher.hash(password), now]
        )
        try db.exec(
            "INSERT OR IGNORE INTO streaks (user_id, current_streak, longest_streak, last_active_date) VALUES (?, 0, 0, NULL)",
            [id]
        )
        return User(id: id, username: name, createdAt: now)
    }

    func login(username: String, password: String) throws -> User {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !password.isEmpty else { throw AuthError.emptyFields }

        let rows = try db.query(
            "SELECT id, username, password_hash, created_at FROM users WHERE username = ?",
            [name]
        )
        guard let row = rows.first,
              let id = row["id"] as? Int64,
              let hash = row["password_hash"] as? String,
              PasswordHasher.verify(password, against: hash)
        else { throw AuthError.invalidCredentials }

        return User(id: id, username: name, createdAt: row["created_at"] as? String ?? "")
    }
}

enum PasswordHasher {
    static let iterations: UInt32 = 120_000
    private static let keyLength = 32
    private static let saltLength = 16

    static func hash(_ password: String) -> String {
        var salt = [UInt8](repeating: 0, count: saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        let derived = pbkdf2(password, salt: salt, iterations: iterations)
        return "pbkdf2$\(iterations)$\(Data(salt).base64EncodedString())$\(Data(derived).base64EncodedString())"
    }

    static func verify(_ password: String, against stored: String) -> Bool {
        let parts = stored.split(separator: "$").map(String.init)
        guard parts.count == 4,
              parts[0] == "pbkdf2",
              let rounds = UInt32(parts[1]),
              let salt = Data(base64Encoded: parts[2]),
              let expected = Data(base64Encoded: parts[3])
        else { return false }

        let derived = pbkdf2(password, salt: [UInt8](salt), iterations: rounds)
        return constantTimeEquals([UInt8](expected), derived)
    }

    private static func pbkdf2(_ password: String, salt: [UInt8], iterations: UInt32) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: keyLength)
        let passwordBytes = Array(password.utf8)
        passwordBytes.withUnsafeBufferPointer { pwBuffer in
            pwBuffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: passwordBytes.count) { pwPtr in
                salt.withUnsafeBufferPointer { saltBuffer in
                    output.withUnsafeMutableBufferPointer { outBuffer in
                        _ = CCKeyDerivationPBKDF(
                            CCPBKDFAlgorithm(kCCPBKDF2),
                            pwPtr, passwordBytes.count,
                            saltBuffer.baseAddress, salt.count,
                            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                            iterations,
                            outBuffer.baseAddress, keyLength
                        )
                    }
                }
            }
        }
        return output
    }

    private static func constantTimeEquals(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}
