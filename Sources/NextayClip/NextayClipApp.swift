import AppKit
import Carbon
import SwiftUI

@MainActor private var globalAppDelegate: ClipboardAppDelegate?

private func hotkeyHandler(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async { globalAppDelegate?.openClipboard() }
    return noErr
}

@MainActor
final class ClipboardAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private let settings = AppSettings()
    private lazy var store = ClipboardStore(settings: settings)
    private var settingsWindow: NSWindow?
    private let clipboardMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = store
        if let url = AppResources.bundle.url(forResource: "BrandMark", withExtension: "png") {
            NSApp.applicationIconImage = NSImage(contentsOf: url)
        }
        clipboardMenu.delegate = self
        clipboardMenu.autoenablesItems = false
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Nextay Clip")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "Nextay Clip · ⌘⇧V"
        statusItem.menu = clipboardMenu
        setupHotkey()
        if CommandLine.arguments.contains("--settings") { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openClipboard()
        return false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === clipboardMenu else { return }
        menu.removeAllItems()
        let clips = store.filteredClips
        if clips.isEmpty {
            let empty = NSMenuItem(title: "Copy text to see it here", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, clip) in clips.prefix(settings.menuLimit).enumerated() {
                addClip(clip, to: menu, shortcut: index < 9 ? String(index + 1) : "")
            }
            if clips.count > settings.menuLimit {
                let older = NSMenuItem(title: "More Clips (\(clips.count - settings.menuLimit))", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                submenu.autoenablesItems = false
                for clip in clips.dropFirst(settings.menuLimit) { addClip(clip, to: submenu) }
                older.submenu = submenu
                menu.addItem(older)
            }
        }
        menu.addItem(.separator())
        let clear = item("Clear History…", action: #selector(clearHistory))
        clear.isEnabled = store.clips.contains { !$0.pinned }
        menu.addItem(clear)
        menu.addItem(item(store.isPaused ? "Resume Monitoring" : "Pause Monitoring", action: #selector(toggleMonitoring)))
        menu.addItem(item("Settings…", action: #selector(showSettings), shortcut: ","))
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Click to copy · ⌘V to paste", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(item("Quit Nextay Clip", action: #selector(quit), shortcut: "q"))
    }

    private func addClip(_ clip: Clip, to menu: NSMenu, shortcut: String = "") {
        let preview = clip.text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let title = String(preview.prefix(65)) + (preview.count > 65 ? "…" : "")
        let copy = item(title, action: #selector(copyClip(_:)), shortcut: shortcut)
        copy.representedObject = clip
        if clip.pinned {
            copy.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        }
        copy.toolTip = String(clip.text.prefix(2000)) + "\n\nOption: pin/unpin. Shift+Option: delete."
        menu.addItem(copy)

        let pin = item((clip.pinned ? "Unpin: " : "Pin: ") + String(preview.prefix(55)), action: #selector(togglePin(_:)), shortcut: shortcut)
        pin.representedObject = clip
        pin.isAlternate = true
        pin.keyEquivalentModifierMask = shortcut.isEmpty ? [.option] : [.command, .option]
        menu.addItem(pin)

        let delete = item("Delete: " + String(preview.prefix(55)), action: #selector(deleteClip(_:)), shortcut: shortcut)
        delete.representedObject = clip
        delete.isAlternate = true
        delete.keyEquivalentModifierMask = shortcut.isEmpty ? [.shift, .option] : [.command, .shift, .option]
        menu.addItem(delete)
    }

    private func item(_ title: String, action: Selector, shortcut: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut)
        item.target = self
        return item
    }

    @objc private func copyClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? Clip else { return }
        store.restore(clip)
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? Clip else { return }
        store.togglePin(clip)
    }

    @objc private func deleteClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? Clip else { return }
        store.delete(clip)
    }

    @objc private func toggleMonitoring() { store.isPaused.toggle() }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, store: store) { [weak self] in self?.clearHistory() }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 740),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Nextay Clip Settings"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Pinned clips will be kept."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { store.clearUnpinned() }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func setupHotkey() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x4E585443), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), hotkeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &eventType, nil, nil)
    }

    func openClipboard() {
        statusItem.button?.performClick(nil)
    }
}

// Settings is created only when requested; startup stays in the menu bar.
@main
struct NextayClipApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ClipboardAppDelegate()
        globalAppDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
