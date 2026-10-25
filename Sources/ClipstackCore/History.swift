import Foundation

/// The clipboard history. Newest first, pinned items always on top.
///
/// Copying something that is already in the history moves it to the top
/// instead of adding a duplicate. Pinned items are never evicted by the limit.
public struct History: Codable, Equatable {
    public private(set) var items: [ClipItem] = []
    public var limit: Int

    public init(items: [ClipItem] = [], limit: Int = 200) {
        self.items = items
        self.limit = max(1, limit)
        sort()
        trim()
    }

    /// Returns false when the text was ignored (blank or too large).
    @discardableResult
    public mutating func add(_ text: String, sourceApp: String? = nil, at date: Date = Date(), maxLength: Int = 1_000_000) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= maxLength else {
            return false
        }
        if let i = items.firstIndex(where: { $0.text == text }) {
            var item = items.remove(at: i)
            item.copiedAt = date
            item.sourceApp = sourceApp ?? item.sourceApp
            items.insert(item, at: 0)
        } else {
            items.insert(ClipItem(text: text, copiedAt: date, sourceApp: sourceApp), at: 0)
        }
        sort()
        trim()
        return true
    }

    public mutating func togglePin(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].pinned.toggle()
        sort()
        trim()
    }

    public mutating func markUsed(_ id: UUID, at date: Date = Date()) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].useCount += 1
        items[i].copiedAt = date
        sort()
    }

    public mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Clears everything except pinned items.
    public mutating func clear() {
        items.removeAll { !$0.pinned }
    }

    public mutating func setLimit(_ n: Int) {
        limit = max(1, n)
        trim()
    }

    public func filtered(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items
            .compactMap { item in Self.score(q, item).map { (item, $0) } }
            .sorted { a, b in
                if a.0.pinned != b.0.pinned { return a.0.pinned }
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.copiedAt > b.0.copiedAt
            }
            .map(\.0)
    }

    /// Matches the text first. Typing an app name ("terminal", "safari") also
    /// finds what was copied there, ranked below direct text matches.
    private static func score(_ query: String, _ item: ClipItem) -> Int? {
        let text = Fuzzy.score(query: query, in: item.text)
        let app = item.sourceApp.flatMap { Fuzzy.score(query: query, in: $0) }.map { $0 / 4 }
        switch (text, app) {
        case let (t?, a?): return max(t, a)
        case let (t?, nil): return t
        case let (nil, a?): return a
        case (nil, nil): return nil
        }
    }

    private mutating func sort() {
        // Stable: pinned first, then by recency.
        items = items.enumerated().sorted { a, b in
            if a.element.pinned != b.element.pinned { return a.element.pinned }
            if a.element.copiedAt != b.element.copiedAt { return a.element.copiedAt > b.element.copiedAt }
            return a.offset < b.offset
        }.map(\.element)
    }

    private mutating func trim() {
        var unpinnedSeen = 0
        items = items.filter { item in
            if item.pinned { return true }
            unpinnedSeen += 1
            return unpinnedSeen <= limit
        }
    }
}
