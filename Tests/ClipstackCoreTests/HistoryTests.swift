import XCTest
@testable import ClipstackCore

final class HistoryTests: XCTestCase {
    func date(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }

    func testNewestFirstAndDedupe() {
        var h = History()
        h.add("one", at: date(1))
        h.add("two", at: date(2))
        h.add("one", at: date(3))
        XCTAssertEqual(h.items.map(\.text), ["one", "two"])
    }

    func testIgnoresBlankAndHuge() {
        var h = History()
        XCTAssertFalse(h.add("   \n\t"))
        XCTAssertFalse(h.add(String(repeating: "x", count: 11), maxLength: 10))
        XCTAssertTrue(h.items.isEmpty)
    }

    func testPinnedStayOnTopAndSurviveLimit() {
        var h = History(limit: 2)
        h.add("keep", at: date(1))
        h.togglePin(h.items[0].id)
        h.add("a", at: date(2))
        h.add("b", at: date(3))
        h.add("c", at: date(4))
        XCTAssertEqual(h.items.map(\.text), ["keep", "c", "b"])
    }

    func testClearKeepsPins() {
        var h = History()
        h.add("pin me", at: date(1))
        h.togglePin(h.items[0].id)
        h.add("gone", at: date(2))
        h.clear()
        XCTAssertEqual(h.items.map(\.text), ["pin me"])
    }

    func testMarkUsedMovesToTop() {
        var h = History()
        h.add("old", at: date(1))
        h.add("new", at: date(2))
        let old = h.items[1].id
        h.markUsed(old, at: date(3))
        XCTAssertEqual(h.items.map(\.text), ["old", "new"])
        XCTAssertEqual(h.items[0].useCount, 1)
    }

    func testFilterRanksSubstringOverScattered() {
        var h = History()
        h.add("git status", at: date(1))
        h.add("great big table", at: date(2))
        h.add("unrelated", at: date(3))
        let results = h.filtered("git").map(\.text)
        XCTAssertEqual(results.first, "git status")
        XCTAssertTrue(results.contains("great big table"))
        XCTAssertFalse(results.contains("unrelated"))
    }

    func testFuzzyRejectsWidelyScatteredLetters() {
        XCTAssertNotNil(Fuzzy.score(query: "gst", in: "git status"))
        XCTAssertNil(Fuzzy.score(query: "term", in: "SELECT id FROM users WHERE created_at > now()"))
    }

    func testFilterFindsBySourceAppBelowTextMatches() {
        var h = History()
        h.add("ls -la", sourceApp: "Terminal", at: date(1))
        h.add("terminal velocity notes", sourceApp: "Notes", at: date(2))
        h.add("unrelated", sourceApp: "Safari", at: date(3))
        XCTAssertEqual(h.filtered("terminal").map(\.text), ["terminal velocity notes", "ls -la"])
    }

    func testFilterNeedsEveryWord() {
        var h = History()
        h.add("ssh deploy@prod", at: date(1))
        h.add("ssh staging", at: date(2))
        XCTAssertEqual(h.filtered("ssh prod").map(\.text), ["ssh deploy@prod"])
    }

    func testPreview() {
        let item = ClipItem(text: "\n\n   first    line  \nsecond")
        XCTAssertEqual(item.preview, "first line")
        XCTAssertEqual(item.lineCount, 4)
    }

    func testLoweringLimitTrims() {
        var h = History(limit: 5)
        for i in 0..<5 { h.add("\(i)", at: date(Double(i))) }
        h.setLimit(2)
        XCTAssertEqual(h.items.map(\.text), ["4", "3"])
    }
}

final class CapturePolicyTests: XCTestCase {
    func testSkipsConcealedTypes() {
        let p = CapturePolicy()
        XCTAssertFalse(p.shouldCapture(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"], frontmostBundleID: nil))
        XCTAssertTrue(p.shouldCapture(types: ["public.utf8-plain-text"], frontmostBundleID: "com.apple.Safari"))
    }

    func testSkipsIgnoredApps() {
        let p = CapturePolicy(ignoredApps: ["com.example.Vault"])
        XCTAssertFalse(p.shouldCapture(types: ["public.utf8-plain-text"], frontmostBundleID: "com.EXAMPLE.vault"))
    }
}

final class StoreTests: XCTestCase {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
    }

    func testRoundTripWithPrivatePermissions() throws {
        let store = Store(url: tempURL())
        var h = History()
        h.add("secret-ish", sourceApp: "Terminal")
        h.togglePin(h.items[0].id)
        try store.save(h)

        let attrs = try FileManager.default.attributesOfItem(atPath: store.url.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)

        let loaded = store.load(limit: 200)
        XCTAssertEqual(loaded.items.map(\.text), ["secret-ish"])
        XCTAssertTrue(loaded.items[0].pinned)
        XCTAssertEqual(loaded.items[0].sourceApp, "Terminal")
    }

    func testCorruptFileIsSetAside() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let h = Store(url: url).load(limit: 10)
        XCTAssertTrue(h.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.deletingPathExtension().appendingPathExtension("corrupt.json").path))
    }
}
