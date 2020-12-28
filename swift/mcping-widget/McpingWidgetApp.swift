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
        let mcInfo = get_server_status("mc.cldfire.net")
        print("Latency to server: \(mcInfo.latency), online players: \(mcInfo.players.online)/\(mcInfo.players.max)")
        
        if let description_cstr = mcInfo.description {
            let description = String.init(cString: description_cstr)
            print("Description: \(description)")
        } else {
            print("Returned string was null!")
        }
        
        let players = Array(UnsafeBufferPointer(start: mcInfo.players.sample, count: Int(mcInfo.players.sample_len)))
        print("Players: \(players)")
        
        free_mcinfo(mcInfo)
    }
}
