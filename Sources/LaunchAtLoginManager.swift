// Wraps ServiceManagement APIs for Launch at Login status and toggling.
import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }

        return false
    }

    var isConfigurable: Bool {
        if #available(macOS 13.0, *) {
            return true
        }

        return false
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw NSError(
                domain: "MyCustomMenu.LaunchAtLogin",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Launch at Login requires macOS 13 or newer."]
            )
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
