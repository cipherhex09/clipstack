import Foundation

public struct ClipItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var pinned: Bool
    public var copiedAt: Date
    /// Name of the app that was frontmost when the text was copied.
    public var sourceApp: String?
    public var useCount: Int

    public init(id: UUID = UUID(), text: String, pinned: Bool = false, copiedAt: Date = Date(), sourceApp: String? = nil, useCount: Int = 0) {
        self.id = id
        self.text = text
        self.pinned = pinned
        self.copiedAt = copiedAt
        self.sourceApp = sourceApp
        self.useCount = useCount
    }

    /// First non-empty line, whitespace collapsed, for list rows.
    public var preview: String {
        let line = text.split(whereSeparator: \.isNewline).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        return line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public var lineCount: Int {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
    }
}
