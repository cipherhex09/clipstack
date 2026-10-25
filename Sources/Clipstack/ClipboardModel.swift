import AppKit
import ClipstackCore
import ServiceManagement

final class ClipboardModel: ObservableObject {
    @Published private(set) var history: History
    @Published var query = "" { didSet { selection = 0 } }
    @Published var selection = 0
    @Published var paused = false
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) } }
    @Published var limit: Int {
        didSet {
            defaults.set(limit, forKey: Keys.limit)
            history.setLimit(limit)
            scheduleSave()
        }
    }

    var onDismiss: () -> Void = {}

    private let store = Store(url: Store.defaultURL)
    private let defaults = UserDefaults.standard
    private var policy = CapturePolicy()
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var saveWork: DispatchWorkItem?
    /// Set when Clipstack itself writes to the pasteboard, so it does not record its own paste.
    private var ownChangeCount: Int?

    private enum Keys {
        static let autoPaste = "autoPaste"
        static let limit = "historyLimit"
        static let ignoredApps = "ignoredApps"
    }

    init() {
        defaults.register(defaults: [Keys.autoPaste: true, Keys.limit: 200])
        let limit = defaults.integer(forKey: Keys.limit)
        self.limit = limit
        autoPaste = defaults.bool(forKey: Keys.autoPaste)
        history = store.load(limit: limit)
        if let apps = defaults.stringArray(forKey: Keys.ignoredApps) {
            policy.ignoredApps = apps
        }
    }

    var visibleItems: [ClipItem] { history.filtered(query) }

    var canAutoPaste: Bool { AXIsProcessTrusted() }

    func start() {
        // Polling is how every macOS clipboard tool works: there is no
        // pasteboard change notification. Twice a second costs nothing.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
        timer?.tolerance = 0.2
    }

    func prepareForShow() {
        query = ""
        selection = 0
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if paused || pb.changeCount == ownChangeCount { return }

        let types = pb.types?.map(\.rawValue) ?? []
        let front = NSWorkspace.shared.frontmostApplication
        guard policy.shouldCapture(types: types, frontmostBundleID: front?.bundleIdentifier),
              let text = pb.string(forType: .string)
        else { return }

        if history.add(text, sourceApp: front?.localizedName) {
            scheduleSave()
        }
    }

    // MARK: Actions

    func choose(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        ownChangeCount = pb.changeCount
        history.markUsed(item.id)
        scheduleSave()
        onDismiss()

        if autoPaste && canAutoPaste {
            // Give the panel a moment to close so the keystroke lands in the
            // app underneath it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Self.sendCommandV() }
        }
    }

    func chooseSelected() {
        let items = visibleItems
        guard items.indices.contains(selection) else { return }
        choose(items[selection])
    }

    func choose(number n: Int) {
        let items = visibleItems
        guard items.indices.contains(n - 1) else { return }
        choose(items[n - 1])
    }

    func moveSelection(_ delta: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func togglePin(_ item: ClipItem) {
        history.togglePin(item.id)
        scheduleSave()
    }

    func togglePinSelected() {
        let items = visibleItems
        guard items.indices.contains(selection) else { return }
        togglePin(items[selection])
    }

    func delete(_ item: ClipItem) {
        history.remove(item.id)
        selection = min(selection, max(visibleItems.count - 1, 0))
        scheduleSave()
    }

    func deleteSelected() {
        let items = visibleItems
        guard items.indices.contains(selection) else { return }
        delete(items[selection])
    }

    func clearHistory() {
        history.clear()
        scheduleSave()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Clipstack: launch at login failed: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }

    // MARK: Saving

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        do {
            try store.save(history)
        } catch {
            NSLog("Clipstack: could not save history: \(error.localizedDescription)")
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
