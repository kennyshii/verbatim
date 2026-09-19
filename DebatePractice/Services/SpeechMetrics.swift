import Foundation

struct FillerHit: Identifiable, Hashable {
    let phrase: String
    let count: Int
    var id: String { phrase }
}

struct SpeechMetrics: Hashable {
    let wordCount: Int
    let fillerCount: Int
    let hits: [FillerHit]
    let fillerScore: Int
    let smoothness: Int
    let smoothnessNotes: [String]
    let tone: Int
    let toneLabel: String
    let toneNotes: [String]

    static let fillerPenalty = 5
    static let empty = SpeechMetrics(wordCount: 0, fillerCount: 0, hits: [], fillerScore: 100, smoothness: 100, smoothnessNotes: [], tone: 100, toneLabel: "—", toneNotes: [])

    var overall: Int {
        guard wordCount > 0 else { return 100 }
        return Int((Double(fillerScore) * 0.4 + Double(smoothness) * 0.3 + Double(tone) * 0.3).rounded())
    }

    var percent: Int { overall }

    var fillerSummary: String {
        guard wordCount > 0 else { return "Nothing to measure yet." }
        if fillerCount == 0 { return "\(wordCount) words, no filler words. Full marks." }
        let list = hits.map { "\($0.phrase) ×\($0.count)" }.joined(separator: ", ")
        return "\(wordCount) words · \(fillerCount) filler\(fillerCount == 1 ? "" : "s") (−\(Self.fillerPenalty) each): \(list)"
    }

    var smoothnessSummary: String {
        guard wordCount > 0 else { return "Nothing to measure yet." }
        return smoothnessNotes.isEmpty ? "Sentences flow: no run-ons, fragments, or restarts." : smoothnessNotes.joined(separator: " · ")
    }

    var toneSummary: String {
        guard wordCount > 0 else { return "Nothing to measure yet." }
        return toneNotes.isEmpty ? "\(toneLabel)." : "\(toneLabel): " + toneNotes.joined(separator: " · ")
    }

    private static let alwaysFillers = [
        "um", "umm", "uh", "uhh", "er", "erm", "ah", "hmm", "mhm",
        "you know", "i mean", "basically", "literally", "actually", "honestly", "obviously",
        "kind of", "sort of", "kinda", "sorta", "okay so", "so yeah", "or whatever",
        "stuff like that", "things like that", "you know what i mean", "at the end of the day",
    ]

    private static let contextualPatterns: [(String, String)] = [
        ("like", #"(?:,\s*like\b|\blike,)"#),
        ("so", #"(?:^|[.!?,]\s*)so,"#),
        ("well", #"(?:^|[.!?,]\s*)well,"#),
        ("right?", #"\bright\?"#),
    ]

    private static let hedges = ["i think", "i guess", "maybe", "perhaps", "probably", "i feel like", "not sure", "might be", "i suppose", "in my opinion", "kind of", "sort of", "a little bit", "i'm not an expert"]
    private static let hostile = ["stupid", "dumb", "idiot", "idiotic", "shut up", "ridiculous", "nonsense", "moron", "pathetic", "you people", "liar", "garbage"]
    private static let absolutes = ["always", "never", "everyone", "nobody", "no one", "everybody", "obviously", "clearly", "undeniably", "without a doubt"]

    static func analyze(_ text: String) -> SpeechMetrics {
        let normalized = text.replacingOccurrences(of: "’", with: "'").lowercased()
        let words = normalized.split { $0.isWhitespace || $0.isNewline }.map(String.init)
        guard !words.isEmpty else { return .empty }

        var counts: [String: Int] = [:]
        for phrase in alwaysFillers {
            let n = matches(#"\b"# + NSRegularExpression.escapedPattern(for: phrase) + #"\b"#, in: normalized)
            if n > 0 { counts[phrase, default: 0] += n }
        }
        for (label, pattern) in contextualPatterns {
            let n = matches(pattern, in: normalized)
            if n > 0 { counts[label, default: 0] += n }
        }
        let hits = counts.map { FillerHit(phrase: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.phrase < $1.phrase }
        let fillerCount = hits.reduce(0) { $0 + $1.count }
        let fillerScore = max(0, 100 - fillerCount * fillerPenalty)

        let (smooth, smoothNotes) = smoothness(normalized: normalized, words: words)
        let (toneScore, label, toneNotes) = tone(original: text, normalized: normalized, words: words)

        return SpeechMetrics(wordCount: words.count, fillerCount: fillerCount, hits: hits, fillerScore: fillerScore,
                             smoothness: smooth, smoothnessNotes: smoothNotes, tone: toneScore, toneLabel: label, toneNotes: toneNotes)
    }

    static func analyze(turns: [String]) -> SpeechMetrics {
        analyze(turns.joined(separator: "\n"))
    }

    private static func smoothness(normalized: String, words: [String]) -> (Int, [String]) {
        var score = 100
        var notes: [String] = []

        let sentences = normalized
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let lengths = sentences.map { $0.split(separator: " ").count }

        let runOns = lengths.filter { $0 > 35 }.count
        if runOns > 0 { score -= runOns * 6; notes.append("\(runOns) run-on sentence\(runOns == 1 ? "" : "s") over 35 words") }

        let fragments = sentences.enumerated().filter { $0.offset > 0 && lengths[$0.offset] < 3 }.count
        if fragments > 0 { score -= fragments * 3; notes.append("\(fragments) fragment\(fragments == 1 ? "" : "s") under 3 words") }

        var stumbles = 0
        for i in 1..<words.count where words[i] == words[i - 1] && words[i].count > 1 && words[i].rangeOfCharacter(from: .letters) != nil { stumbles += 1 }
        if stumbles > 0 { score -= stumbles * 5; notes.append("\(stumbles) repeated word\(stumbles == 1 ? "" : "s") (\"the the\")") }

        let restarts = matches(#"(\.\.\.|—|--|\s-\s)"#, in: normalized)
        if restarts > 0 { score -= restarts * 3; notes.append("\(restarts) restart\(restarts == 1 ? "" : "s") or trailing off") }

        let commaHeavy = sentences.filter { $0.filter { $0 == "," }.count >= 5 }.count
        if commaHeavy > 0 { score -= commaHeavy * 3; notes.append("\(commaHeavy) sentence\(commaHeavy == 1 ? "" : "s") with 5+ commas") }

        if !lengths.isEmpty {
            let mean = Double(lengths.reduce(0, +)) / Double(lengths.count)
            if mean > 30 { score -= 6; notes.append("average sentence is \(Int(mean)) words — break them up") }
            if sentences.count == 1 && words.count > 25 { score -= 6; notes.append("one long breath with no full stops") }
        }

        return (max(0, min(100, score)), notes)
    }

    private static func tone(original: String, normalized: String, words: [String]) -> (Int, String, [String]) {
        var score = 100
        var notes: [String] = []

        var hedgeCount = 0
        for h in hedges { hedgeCount += matches(#"\b"# + NSRegularExpression.escapedPattern(for: h) + #"\b"#, in: normalized) }
        if hedgeCount > 0 { score -= hedgeCount * 4; notes.append("\(hedgeCount) hedge\(hedgeCount == 1 ? "" : "s") (\"I think\", \"maybe\")") }

        var hostileCount = 0
        for h in hostile { hostileCount += matches(#"\b"# + NSRegularExpression.escapedPattern(for: h) + #"\b"#, in: normalized) }
        if hostileCount > 0 { score -= hostileCount * 12; notes.append("\(hostileCount) hostile word\(hostileCount == 1 ? "" : "s")") }

        let shouting = original.split { $0.isWhitespace }.filter { w in w.count >= 3 && w.allSatisfy { $0.isUppercase || !$0.isLetter } && w.contains { $0.isLetter } }.count
        if shouting > 0 { score -= shouting * 3; notes.append("\(shouting) all-caps word\(shouting == 1 ? "" : "s")") }

        let exclaims = matches(#"!{2,}|\?{2,}"#, in: original)
        if exclaims > 0 { score -= exclaims * 3; notes.append("stacked punctuation (!! or ??)") }

        var absoluteCount = 0
        for a in absolutes { absoluteCount += matches(#"\b"# + NSRegularExpression.escapedPattern(for: a) + #"\b"#, in: normalized) }
        if absoluteCount > 2 { score -= min(12, (absoluteCount - 2) * 3); notes.append("\(absoluteCount) absolutes (\"always\", \"everyone\") — easy to refute") }

        let label: String
        if hostileCount > 0 || shouting >= 3 { label = "Overheated" }
        else if hedgeCount >= 3 { label = "Hedging" }
        else if score >= 85 { label = "Confident and measured" }
        else { label = "Uneven" }

        return (max(0, min(100, score)), label, notes)
    }

    private static func matches(_ pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    static func containsStatistic(_ text: String) -> Bool {
        matches(#"(\d[\d,.]*\s*(%|percent|million|billion|trillion|thousand)|\$\s*\d|\d+\s*(out of|in every|per)\s+\d+|\b\d+x\b)"#, in: text.lowercased()) > 0
    }
}
