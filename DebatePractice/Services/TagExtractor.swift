import Foundation

struct FeedbackTag: Identifiable, Equatable {
    let name: String
    let count: Int
    var id: String { name }
}

enum TagExtractor {
    static let rules: [(tag: String, keywords: [String])] = [
        ("Rebuttals", ["rebut", "refut", "counter", "respond to", "réfut", "réplique", "contraargument"]),
        ("Evidence use", ["evidence", "example", "data", "statistic", "source", "cite", "support your", "evidencia", "ejemplo", "preuve", "exemple"]),
        ("Structure", ["structure", "organiz", "organis", "outline", "signpost", "estructura", "organiza"]),
        ("Clarity", ["clarity", "clear", "vague", "unclear", "precise", "specific", "claridad", "claro", "clarté", "clair", "vago", "vague"]),
        ("Logical reasoning", ["logic", "assumption", "fallacy", "reasoning", "warrant", "premise", "lógica", "logique", "suposición", "supposition", "razonamiento", "raisonnement"]),
        ("Handling concessions", ["concede", "concession", "acknowledge", "grant that", "conced", "reconoc", "reconna"]),
        ("Impact and stakes", ["impact", "consequence", "why it matters", "stakes", "impacto", "consecuencia", "conséquence", "enjeu"]),
    ]

    static func recurring(in sessions: [SessionRecord], minCount: Int = 2) -> [FeedbackTag] {
        var counts: [String: Int] = [:]
        for session in sessions {
            guard let feedback = session.feedback else { continue }
            let text = feedback.improvementText.lowercased()
            for rule in rules where rule.keywords.contains(where: { text.contains($0) }) {
                counts[rule.tag, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= minCount }
            .map { FeedbackTag(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }
}
