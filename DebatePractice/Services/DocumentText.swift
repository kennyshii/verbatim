import Foundation
import PDFKit
import Compression
import UniformTypeIdentifiers

enum DocumentTextError: LocalizedError {
    case unreadable(String)
    case unsupported(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): return "Couldn't read \(name). Try exporting it as a PDF or plain text."
        case .unsupported(let ext): return "\(ext.uppercased()) files aren't supported. Use PDF, DOCX, TXT, RTF, or Markdown."
        case .empty: return "That file has no readable text in it."
        }
    }
}

enum DocumentText {
    static let allowedTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .rtf, .text]
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        return types
    }()

    static func extract(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let text: String

        switch ext {
        case "pdf":
            guard let document = PDFDocument(url: url) else { throw DocumentTextError.unreadable(name) }
            text = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n")
        case "docx":
            guard let data = try? Data(contentsOf: url) else { throw DocumentTextError.unreadable(name) }
            text = try docxText(data)
        case "rtf", "rtfd":
            guard let data = try? Data(contentsOf: url),
                  let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            else { throw DocumentTextError.unreadable(name) }
            text = attributed.string
        case "txt", "md", "markdown", "text", "":
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                text = utf8
            } else if let latin = try? String(contentsOf: url, encoding: .isoLatin1) {
                text = latin
            } else {
                throw DocumentTextError.unreadable(name)
            }
        case "doc", "pages":
            throw DocumentTextError.unsupported(ext)
        default:
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { throw DocumentTextError.unsupported(ext) }
            text = raw
        }

        let cleaned = normalize(text)
        guard !cleaned.isEmpty else { throw DocumentTextError.empty }
        return cleaned
    }

    static func suggestedTitle(from text: String, filename: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count > 8 }
        if let firstLine, firstLine.lowercased().hasPrefix("a bill") {
            return String(firstLine.prefix(160))
        }
        if let firstLine, firstLine.count <= 160 { return firstLine }
        return (filename as NSString).deletingPathExtension
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func docxText(_ data: Data) throws -> String {
        guard let xml = zipEntry(named: "word/document.xml", in: data) else {
            throw DocumentTextError.unreadable("the .docx")
        }
        guard let markup = String(data: xml, encoding: .utf8) else { throw DocumentTextError.unreadable("the .docx") }
        var text = markup
            .replacingOccurrences(of: "</w:p>", with: "\n")
            .replacingOccurrences(of: "<w:br/>", with: "\n")
            .replacingOccurrences(of: "<w:tab/>", with: " ")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, replacement) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'")] {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text
    }

    private static func zipEntry(named target: String, in data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 22 else { return nil }

        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }

        var eocd = -1
        var index = bytes.count - 22
        let limit = max(0, bytes.count - 66_000)
        while index >= limit {
            if u32(index) == 0x06054b50 { eocd = index; break }
            index -= 1
        }
        guard eocd >= 0 else { return nil }

        let entryCount = u16(eocd + 10)
        var offset = u32(eocd + 16)

        for _ in 0..<entryCount {
            guard offset + 46 <= bytes.count, u32(offset) == 0x02014b50 else { return nil }
            let method = u16(offset + 10)
            let compressedSize = u32(offset + 20)
            let uncompressedSize = u32(offset + 24)
            let nameLength = u16(offset + 28)
            let extraLength = u16(offset + 30)
            let commentLength = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let nameBytes = Array(bytes[(offset + 46)..<(offset + 46 + nameLength)])
            let name = String(decoding: nameBytes, as: UTF8.self)

            if name == target {
                guard localOffset + 30 <= bytes.count, u32(localOffset) == 0x04034b50 else { return nil }
                let localNameLength = u16(localOffset + 26)
                let localExtraLength = u16(localOffset + 28)
                let start = localOffset + 30 + localNameLength + localExtraLength
                guard start + compressedSize <= bytes.count else { return nil }
                let payload = Array(bytes[start..<(start + compressedSize)])
                if method == 0 { return Data(payload) }
                guard method == 8 else { return nil }
                return inflate(payload, expected: uncompressedSize)
            }
            offset += 46 + nameLength + extraLength + commentLength
        }
        return nil
    }

    private static func inflate(_ payload: [UInt8], expected: Int) -> Data? {
        let capacity = max(expected, payload.count * 8) + 4096
        var output = [UInt8](repeating: 0, count: capacity)
        let written = payload.withUnsafeBufferPointer { input -> Int in
            output.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(destination.baseAddress!, capacity,
                                          input.baseAddress!, payload.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return Data(output[0..<written])
    }
}
