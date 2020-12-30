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
        print(mcInfo)
    }
}
