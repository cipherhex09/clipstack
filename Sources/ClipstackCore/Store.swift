import Foundation

/// Saves the history as JSON with owner-only permissions. Clipboard history
/// can hold things you would not want another user account to read.
public struct Store {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Clipstack", isDirectory: true).appendingPathComponent("history.json")
    }

    public func load(limit: Int) -> History {
        guard let data = try? Data(contentsOf: url) else { return History(limit: limit) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var history = try? decoder.decode(History.self, from: data) else {
            // A corrupt file should not crash the app or be silently overwritten.
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return History(limit: limit)
        }
        history.setLimit(limit)
        return history
    }

    public func save(_ history: History) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
