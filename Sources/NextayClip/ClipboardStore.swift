import AppKit
import Combine
import Foundation

struct Clip: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = Date()
    var pinned: Bool = false
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published private(set) var storageError: String?
    let settings: AppSettings
    let directoryURL: URL

    var filteredClips: [Clip] {
        clips.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.createdAt > $1.createdAt
        }
    }
    var isPaused: Bool {
        get { settings.isPaused }
        set { settings.isPaused = newValue }
    }

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?
    private var settingsSubscription: AnyCancellable?
    private let fileURL: URL
    private var lastCleanup = Date.distantPast

    init(settings: AppSettings, directoryURL: URL? = nil,
         pasteboard: NSPasteboard = .general, startMonitoring: Bool = true) {
        self.settings = settings
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
        self.directoryURL = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NextayClip", isDirectory: true)
        fileURL = self.directoryURL.appendingPathComponent("history.json")
        do {
            try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
            // Migrate only real app data, never injected test directories.
            if directoryURL == nil && !FileManager.default.fileExists(atPath: fileURL.path) {
                let previous = self.directoryURL.deletingLastPathComponent()
                    .appendingPathComponent("NextayClipboard/history.json")
                if FileManager.default.fileExists(atPath: previous.path) {
                    try FileManager.default.copyItem(at: previous, to: fileURL)
                }
            }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                clips = try JSONDecoder().decode([Clip].self, from: Data(contentsOf: fileURL))
            }
        } catch {
            storageError = "Could not load clipboard history: \(error.localizedDescription)"
        }
        // Published values arrive before assignment; use the supplied new values.
        settingsSubscription = settings.$historyLimit.combineLatest(settings.$retentionDays)
            .sink { [weak self] limit, days in
                self?.trimAndSave(limit: limit, retentionDays: days)
            }
        if startMonitoring {
            timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
        }
    }

    func poll(now: Date = Date()) {
        if now.timeIntervalSince(lastCleanup) >= 60 {
            trimAndSave(now: now)
            lastCleanup = now
        }
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard !isPaused, let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let value = String(text.prefix(100_000))
        // Re-copying a pinned item updates that item, rather than duplicating it.
        if let index = clips.firstIndex(where: { $0.text == value }) {
            clips[index].createdAt = now
        } else {
            clips.insert(Clip(text: value, createdAt: now), at: 0)
        }
        trimAndSave(now: now, forceSave: true)
    }

    func restore(_ clip: Clip) {
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[index].pinned.toggle()
        trimAndSave(forceSave: true)
    }

    func delete(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        save()
    }

    func clearUnpinned() {
        clips.removeAll { !$0.pinned }
        save()
    }

    private func trimAndSave(limit: Int? = nil, retentionDays: Int? = nil, now: Date = Date(), forceSave: Bool = false) {
        let previous = clips
        let days = retentionDays ?? settings.retentionDays
        if days > 0 {
            let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
            clips.removeAll { !$0.pinned && $0.createdAt < cutoff }
        }
        let pinned = clips.filter(\.pinned)
        let recent = clips.filter { !$0.pinned }.sorted { $0.createdAt > $1.createdAt }
            .prefix(limit ?? settings.historyLimit)
        clips = pinned + recent
        if forceSave || clips != previous { save() }
    }

    private func save() {
        do {
            try JSONEncoder().encode(clips).write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "Could not save clipboard history: \(error.localizedDescription)"
        }
    }
}
