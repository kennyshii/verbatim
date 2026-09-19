import Foundation

enum FeedbackParser {
    static let notProvided = "Not provided."

    static func parse(_ raw: String) -> DebateFeedback {
        let labels: [[String]] = [
            ["strongest argument", "strongest answer"],
            ["weakest argument", "weakest answer"],
            ["missed rebuttal opportunity", "missed rebuttal", "missed opportunity in refutation or questioning", "missed opportunity"],
            ["concrete suggestion for next time", "concrete suggestion", "suggestion for next time", "suggestion"],
        ]
        guard let parts = sections(raw, labels: labels) else {
            let fallback = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return DebateFeedback(strongestArgument: fallback.isEmpty ? notProvided : fallback,
                                  weakestArgument: notProvided, missedRebuttal: notProvided, suggestion: notProvided)
        }
        return DebateFeedback(strongestArgument: parts[0], weakestArgument: parts[1], missedRebuttal: parts[2], suggestion: parts[3])
    }

    static func parseDecision(_ raw: String, affirmative: String, negative: String) -> JudgeDecision {
        let labels: [[String]] = [
            ["decision"],
            ["reason for decision", "rfd"],
            ["feedback for the affirmative", "feedback for affirmative", "affirmative feedback", "feedback for \(affirmative.lowercased())"],
            ["feedback for the negative", "feedback for negative", "negative feedback", "feedback for \(negative.lowercased())"],
        ]
        guard let parts = sections(raw, labels: labels) else {
            let fallback = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return JudgeDecision(winner: notProvided, reasonForDecision: fallback.isEmpty ? notProvided : fallback,
                                 affirmativeFeedback: notProvided, negativeFeedback: notProvided)
        }
        return JudgeDecision(winner: parts[0], reasonForDecision: parts[1], affirmativeFeedback: parts[2], negativeFeedback: parts[3])
    }

    static func sections(_ raw: String, labels: [[String]]) -> [String]? {
        var buckets: [Int: [String]] = [:]
        var current: Int?

        for line in raw.components(separatedBy: .newlines) {
            if let (index, remainder) = matchLabel(line, labels: labels) {
                current = index
                if !remainder.isEmpty { buckets[index, default: []].append(remainder) }
            } else if let index = current {
                buckets[index, default: []].append(line)
            }
        }
        guard !buckets.isEmpty else { return nil }

        return (0..<labels.count).map { index in
            let joined = (buckets[index] ?? []).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? notProvided : joined
        }
    }

    private static func matchLabel(_ line: String, labels: [[String]]) -> (Int, String)? {
        let decoration = CharacterSet(charactersIn: "#*_-•>0123456789.) \t")
        let stripped = String(line.drop { $0.unicodeScalars.allSatisfy(decoration.contains) })
            .trimmingCharacters(in: .whitespaces)
        let lower = stripped.lowercased()

        for (index, variants) in labels.enumerated() {
            for label in variants where lower.hasPrefix(label) {
                var rest = String(stripped.dropFirst(label.count))
                if rest.trimmingCharacters(in: .whitespaces).hasPrefix("("),
                   let close = rest.firstIndex(of: ")") {
                    rest = String(rest[rest.index(after: close)...])
                }
                rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: ":*_ \t"))
                return (index, rest)
            }
        }
        return nil
    }
}
