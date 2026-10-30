import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let historyLimits = [50, 100, 250, 500, 1000]
    static let retentionOptions = [0, 1, 7, 30, 90]
    static let menuLimits = [10, 25, 50]

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: "historyLimit") }
    }
    @Published var retentionDays: Int {
        didSet { defaults.set(retentionDays, forKey: "retentionDays") }
    }
    @Published var menuLimit: Int {
        didSet { defaults.set(menuLimit, forKey: "menuLimit") }
    }
    @Published var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: "isPaused") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let limit = defaults.integer(forKey: "historyLimit")
        historyLimit = Self.historyLimits.contains(limit) ? limit : 250
        let days = defaults.integer(forKey: "retentionDays")
        retentionDays = Self.retentionOptions.contains(days) ? days : 0
        let menu = defaults.integer(forKey: "menuLimit")
        menuLimit = Self.menuLimits.contains(menu) ? menu : 25
        isPaused = defaults.bool(forKey: "isPaused")
    }
}
