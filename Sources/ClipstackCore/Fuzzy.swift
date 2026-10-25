import Foundation

/// Small fuzzy matcher. Every word in the query must match the text, either as
/// a substring (scores high) or as letters in order with only small gaps
/// (scores low), so "gst" finds "git status" but "term" does not match any
/// long line that happens to contain t, e, r and m somewhere.
public enum Fuzzy {
    public static func score(query: String, in text: String) -> Int? {
        let hay = text.lowercased()
        var total = 0
        for word in query.lowercased().split(separator: " ") {
            guard let s = wordScore(String(word), in: hay) else { return nil }
            total += s
        }
        return total
    }

    private static func wordScore(_ word: String, in hay: String) -> Int? {
        if let r = hay.range(of: word) {
            // Earlier and word-start matches rank higher.
            let offset = hay.distance(from: hay.startIndex, to: r.lowerBound)
            let atWordStart = r.lowerBound == hay.startIndex || !hay[hay.index(before: r.lowerBound)].isLetter
            return 1000 - min(offset, 500) + (atWordStart ? 200 : 0)
        }
        // Letters in order, with a penalty for gaps.
        var gaps = 0
        var idx = hay.startIndex
        for ch in word {
            guard let found = hay[idx...].firstIndex(of: ch) else { return nil }
            gaps += hay.distance(from: idx, to: found)
            idx = hay.index(after: found)
        }
        guard gaps <= word.count * 2 + 2 else { return nil }
        return max(1, 300 - gaps * 10)
    }
}
