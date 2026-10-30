# Contributing

Issues and pull requests are welcome at https://github.com/NexTay/clip.

1. Fork the repository and create a branch for your change.
2. Keep the menu compact and use native macOS controls. Settings must open only when requested.
3. Run `bash scripts/test.sh` and `bash scripts/build-app.sh` on macOS.
4. Check the app manually: the paperclip menu, clipboard copying, pin/unpin, Settings persistence, and no launch window. Test light/dark mode for UI changes.
5. Open a pull request explaining the behavior changed and how you verified it.

Do not include real clipboard history, personal preferences, credentials, build output, or private text in commits or issue screenshots. Use sample text in bug reports.

## Source map

- `AppSettings.swift`: persisted preferences and allowed values.
- `AppResources.swift`: installed app and development resource-bundle lookup.
- `ClipboardStore.swift`: text capture, history persistence, retention, and pinning.
- `NextayClipApp.swift`: AppKit lifecycle, native menu, hotkey, and Settings window.
- `SettingsView.swift`: minimal SwiftUI settings and company links.
- `Resources/BrandMark.png`: supplied NexTay Solutions mark, bundled for offline use.
- `Tests/NextayClipTests/ClipboardStoreTests.swift`: isolated regression suite.
- `scripts/build-app.sh`: release app packaging, icon creation, and local signing.

The project has no external packages. Keep clipboard data local and disclose any proposed changes to storage or network behavior in your pull request. Contributions are provided under the project's MIT License.
