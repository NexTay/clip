import AppKit
import Foundation

// Standalone tests run with Command Line Tools; no Xcode/XCTest installation is needed.
@main
@MainActor
struct ClipboardStoreTests {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }
    static var checks = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !condition() { throw Failure(description: message) }
    }

    static func withStore(_ action: (ClipboardStore, AppSettings, NSPasteboard, UserDefaults, URL) throws -> Void) throws {
        let suite = "NextayClipTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw Failure(description: "No test defaults") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let pasteboard = NSPasteboard.withUniqueName()
        let settings = AppSettings(defaults: defaults)
        let store = ClipboardStore(settings: settings, directoryURL: directory, pasteboard: pasteboard, startMonitoring: false)
        defer {
            defaults.removePersistentDomain(forName: suite)
            pasteboard.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
        }
        try action(store, settings, pasteboard, defaults, directory)
    }

    static func copy(_ text: String, into pasteboard: NSPasteboard, store: ClipboardStore, now: Date = Date()) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        store.poll(now: now)
    }

    static func testLimit() throws {
        try withStore { store, settings, pasteboard, _, _ in
            let now = Date()
            copy("keep pinned", into: pasteboard, store: store, now: now)
            store.togglePin(store.clips[0])
            for index in 0..<70 {
                copy("clip \(index)", into: pasteboard, store: store, now: now.addingTimeInterval(Double(index + 1)))
            }
            settings.historyLimit = 50
            try expect(store.clips.count == 51, "History limit must preserve pinned clips separately")
            try expect(store.filteredClips.first?.text == "keep pinned", "Pinned clip must sort first")
            try expect(store.filteredClips[1].text == "clip 69", "Recent clips must sort newest first")
            try expect(!store.clips.contains { $0.text == "clip 0" }, "Oldest clips must be removed")
        }
    }

    static func testRetention() throws {
        try withStore { store, settings, pasteboard, _, _ in
            let old = Date().addingTimeInterval(-10 * 86_400)
            copy("old pinned", into: pasteboard, store: store, now: old)
            store.togglePin(store.clips[0])
            copy("old recent", into: pasteboard, store: store, now: old)
            copy("new", into: pasteboard, store: store)
            settings.retentionDays = 7
            try expect(Set(store.clips.map(\.text)) == ["old pinned", "new"], "Retention must apply immediately and preserve pins")
            store.poll(now: Date().addingTimeInterval(8 * 86_400))
            try expect(store.clips.map(\.text) == ["old pinned"], "Timed cleanup must expire unpinned clips without new copies")
        }
    }

    static func testPersistence() throws {
        try withStore { store, settings, pasteboard, defaults, directory in
            copy("saved", into: pasteboard, store: store)
            store.togglePin(store.clips[0])
            settings.historyLimit = 100
            settings.menuLimit = 10
            settings.retentionDays = 30
            settings.isPaused = true
            let restored = AppSettings(defaults: defaults)
            let restoredStore = ClipboardStore(settings: restored, directoryURL: directory,
                                               pasteboard: pasteboard, startMonitoring: false)
            try expect(restored.historyLimit == 100, "History limit must persist")
            try expect(restored.menuLimit == 10, "Menu limit must persist")
            try expect(restored.retentionDays == 30, "Retention must persist")
            try expect(restored.isPaused, "Pause must persist")
            try expect(restoredStore.clips.map(\.text) == ["saved"], "History must persist")
            try expect(restoredStore.clips.first?.pinned == true, "Pin must persist")
        }
    }

    static func testClipboardActions() throws {
        try withStore { store, settings, pasteboard, _, _ in
            settings.isPaused = true
            copy("ignored", into: pasteboard, store: store)
            try expect(store.clips.isEmpty, "Paused monitoring must ignore copies")
            settings.isPaused = false
            copy("   \n", into: pasteboard, store: store)
            try expect(store.clips.isEmpty, "Whitespace must be ignored")
            copy("pinned", into: pasteboard, store: store)
            let pinned = store.clips[0]
            store.togglePin(pinned)
            copy("pinned", into: pasteboard, store: store)
            try expect(store.clips.count == 1 && store.clips[0].pinned, "Re-copying pinned text must not duplicate it")
            copy("recent", into: pasteboard, store: store)
            store.restore(pinned)
            store.poll()
            try expect(pasteboard.string(forType: .string) == "pinned", "Restore must update the pasteboard")
            try expect(store.clips.count == 2, "Restore must not create a new clip")
            store.clearUnpinned()
            try expect(store.clips.map(\.text) == ["pinned"], "Clear must preserve pins")
            store.delete(pinned)
            try expect(store.clips.isEmpty, "Delete must remove a pinned clip")
        }
    }

    static func testDefaultsValidation() throws {
        try withStore { _, _, _, defaults, _ in
            defaults.set(-1, forKey: "historyLimit")
            defaults.set(-100, forKey: "retentionDays")
            defaults.set(9000, forKey: "menuLimit")
            let settings = AppSettings(defaults: defaults)
            try expect(settings.historyLimit == 250, "Invalid history limit must fall back")
            try expect(settings.retentionDays == 0, "Invalid retention must fall back")
            try expect(settings.menuLimit == 25, "Invalid menu limit must fall back")
        }
    }

    static func main() throws {
        try testLimit()
        try testRetention()
        try testPersistence()
        try testClipboardActions()
        try testDefaultsValidation()
        print("Passed \(checks) checks: history limits, retention, persistence, clipboard actions, defaults.")
    }
}
