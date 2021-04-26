//

import SwiftUI

@main
struct MinecraftStatusApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
    }
}

extension MinecraftStatusApp {
    /// App's current version.
    static var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// App's current build number.
    static var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    /// App's current version and build number.
    static var fullVersion: String? {
        guard let version = version else { return nil }
        guard let build = build else { return version }
        return "\(version) (\(build))"
    }
}
