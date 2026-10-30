import Foundation

/// Resolve installed app assets before SwiftPM's development-only fallback.
/// SwiftPM versions differ in where they look for a bundle inside a .app.
enum AppResources {
    static let bundle: Bundle = {
        if let resources = Bundle.main.resourceURL,
           let packaged = Bundle(url: resources.appendingPathComponent("NextayClip_NextayClip.bundle")) {
            return packaged
        }
        return Bundle.module
    }()
}
