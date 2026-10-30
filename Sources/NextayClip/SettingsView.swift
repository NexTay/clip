import AppKit
import ServiceManagement
import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    var onClearHistory: () -> Void
    @ViewState private var loginEnabled = SMAppService.mainApp.status == .enabled
    @ViewState private var loginMessage: String? = nil
    private let brandGreen = Color(red: 0, green: 0.56, blue: 0.36)

    var body: some View {
        VStack(spacing: 0) {
            branding
            Form {
                Section {
                    Toggle("Save copied text", isOn: Binding(
                        get: { !settings.isPaused }, set: { settings.isPaused = !$0 }
                    ))
                    Toggle("Launch at login", isOn: $loginEnabled)
                        .onChange(of: loginEnabled) { enabled in updateLogin(enabled) }
                    LabeledContent("Open clipboard", value: "⌘⇧V")
                } header: { Text("General") }

                Section {
                    Picker("Keep recent clips", selection: $settings.historyLimit) {
                        ForEach(AppSettings.historyLimits, id: \.self) { Text("\($0) clips").tag($0) }
                    }
                    Picker("Delete unpinned clips after", selection: $settings.retentionDays) {
                        Text("Never").tag(0)
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    Picker("Clips shown in menu", selection: $settings.menuLimit) {
                        ForEach(AppSettings.menuLimits, id: \.self) { Text("\($0) clips").tag($0) }
                    }
                } header: { Text("History") } footer: {
                    Text("Changes apply immediately. Pinned clips are kept until you delete them. Older clips are in More Clips.")
                }

                Section {
                    HStack {
                        Text("\(store.clips.count) saved clips")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear History…", action: onClearHistory)
                            .disabled(!store.clips.contains { !$0.pinned })
                    }
                    Button("Show History in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.directoryURL])
                    }
                } header: { Text("Storage") } footer: {
                    Text("Text stays on this Mac, in an unencrypted local file. No cloud sync or analytics. Pause saving before copying sensitive information.")
                }
                if let message = store.storageError ?? loginMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            footer
        }
        .frame(width: 480, height: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(brandGreen)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private var branding: some View {
        HStack(spacing: 14) {
            if let url = AppResources.bundle.url(forResource: "BrandMark", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .frame(width: 60, height: 60)
                    .accessibilityLabel("NexTay Solutions logo")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Nextay Clip").font(.system(size: 23, weight: .semibold))
                Text("by NexTay Solutions")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Settings").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Link("NexTay Solutions ↗", destination: URL(string: "https://nextaysolutions.com/")!)
                Link("Source Code ↗", destination: URL(string: "https://github.com/NexTay/clip")!)
            }
            Text("Free & open source · MIT License · v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0")")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.primary.opacity(0.025))
    }

    private func updateLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled { try service.register() } else { try service.unregister() }
            loginMessage = service.status == .requiresApproval
                ? "Allow Nextay Clip in System Settings → General → Login Items, then return here."
                : nil
        } catch {
            loginMessage = "Could not update login item: \(error.localizedDescription) Install the app in Applications and try again."
        }
        loginEnabled = service.status == .enabled
    }
}
