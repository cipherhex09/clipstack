import ClipstackCore
import SwiftUI

struct ClipListView: View {
    @ObservedObject var model: ClipboardModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 420, height: 480)
        .onAppear { searchFocused = true }
        .onKeyPress(.downArrow) { model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(-1); return .handled }
        .onKeyPress(.return) { model.chooseSelected(); return .handled }
        .onKeyPress(.escape) { model.onDismiss(); return .handled }
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            guard press.modifiers.contains(.command), let n = Int(String(press.characters)) else { return .ignored }
            model.choose(number: n)
            return .handled
        }
        .onKeyPress(keys: ["p"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            model.togglePinSelected()
            return .handled
        }
        .onKeyPress(.delete) {
            // Cmd+Delete removes the item; plain delete edits the search.
            guard NSEvent.modifierFlags.contains(.command) else { return .ignored }
            model.deleteSelected()
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
            if model.paused {
                Text("Paused").font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var list: some View {
        let items = model.visibleItems
        return Group {
            if items.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text(model.query.isEmpty ? "Copy something and it shows up here." : "No matches")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, index: index, selected: index == model.selection)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { model.choose(item) }
                                    .onHover { if $0 { model.selection = index } }
                                    .contextMenu {
                                        Button(item.pinned ? "Unpin" : "Pin") { model.togglePin(item) }
                                        Button("Delete") { model.delete(item) }
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: model.selection) { _, new in
                        if items.indices.contains(new) { proxy.scrollTo(items[new].id) }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.autoPaste && !model.canAutoPaste {
                Button("Allow auto-paste") { model.requestAccessibility() }
                    .buttonStyle(.link)
                    .help("Clipstack needs Accessibility access to press Cmd+V for you. Without it, items are copied and you paste them yourself.")
            } else {
                Text("↩ paste  ⌘P pin  ⌘⌫ delete")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Toggle("Pause recording", isOn: $model.paused)
                Toggle("Paste after choosing", isOn: $model.autoPaste)
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                Picker("Keep", selection: $model.limit) {
                    ForEach([50, 200, 500, 1000], id: \.self) { Text("\($0) items").tag($0) }
                }
                Divider()
                Button("Clear history (keeps pins)") { model.clearHistory() }
                Divider()
                Button("Quit Clipstack") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(index < 9 ? "⌘\(index + 1)" : "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 13))
                HStack(spacing: 6) {
                    if let app = item.sourceApp { Text(app) }
                    Text(item.copiedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                    if item.lineCount > 1 { Text("\(item.lineCount) lines") }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.pinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .help(String(item.text.prefix(600)))
    }
}
