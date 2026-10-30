A minimal clipboard history app for macOS, by [NexTay Solutions](https://nextaysolutions.com/).

## Download and install

Requires **macOS 13 or later**. Every download is **universal**, with both Apple Silicon (`arm64`) and Intel (`x86_64`) executables.

- **Recommended: `.dmg`** — open it, quit any running copy of Nextay Clip, drag the app to Applications, eject the image, and launch from Applications.
- **`.pkg` installer** — quit any running copy of the app, open the installer, and follow the prompts. It installs into `/Applications` and may request administrator approval.
- **`.zip`** — extract and move `NextayClip.app` to Applications.
- **`SHA256SUMS.txt`** — checksums for all three downloads.

These downloads are locally signed, **not Apple-notarized**. If macOS blocks a download or the app, review it under **System Settings → Privacy & Security → Open Anyway**. See [Apple's first-launch guidance](https://support.apple.com/en-us/102445). A Developer ID signed and notarized release is not available yet.

After launching, look for the **paperclip in the menu bar** or press **⌘⇧V**. No main window appears at startup. Click a clip to copy, then **⌘V** to paste. Open **Settings…** to configure history limits, cleanup, menu size, monitoring, and launch at login.

Pinned clips survive cleanup. History stays on the Mac as unencrypted JSON. There are no accounts, cloud sync, or analytics. Pause monitoring before copying sensitive information.

Free to use, modify, and distribute under the MIT License. Full [setup, usage, and privacy documentation](https://github.com/NexTay/clip#readme) is in the repository.
