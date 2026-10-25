import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClipPanel!
    private var hotKey: HotKey?
    let model = ClipboardModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipstack")
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        panel = ClipPanel(rootView: ClipListView(model: model))
        model.onDismiss = { [weak self] in self?.panel.orderOut(nil) }

        // Cmd+Shift+V, the shortcut most clipboard managers use.
        hotKey = HotKey(keyCode: 9, modifiers: [.command, .shift]) { [weak self] in
            self?.togglePanel(nearStatusItem: false)
        }

        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveNow()
    }

    @objc private func statusItemClicked() {
        togglePanel(nearStatusItem: true)
    }

    private func togglePanel(nearStatusItem: Bool) {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }
        model.prepareForShow()
        if nearStatusItem, let button = statusItem.button, let window = button.window {
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            panel.show(below: frame)
        } else {
            panel.showNearMouse()
        }
    }
}
