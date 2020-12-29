// 

import SwiftUI

@main
struct McpingWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    static func main() {
        let mcInfo = McInfo(get_server_status("mc.cldfire.net"))!

        print("Latency to server: \(mcInfo.latency), online players: \(mcInfo.players.online)/\(mcInfo.players.max)")
        print("Description: \(mcInfo.description)")
        print("Players: \(mcInfo.players)")
    }
}
