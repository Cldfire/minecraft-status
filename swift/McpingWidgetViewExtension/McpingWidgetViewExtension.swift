//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> McServerStatusEntry {
        McServerStatusEntry(date: Date(), configuration: ConfigurationIntent(), mcInfo: nil)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (McServerStatusEntry) -> ()) {
        let entry = McServerStatusEntry(date: Date(), configuration: configuration, mcInfo: nil)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        McPinger.ping(configuration.serverAddress ?? "mc.hypixel.net") { mcInfo in
            let entry = McServerStatusEntry(date: currentDate, configuration: configuration, mcInfo: mcInfo)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct McServerStatusEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let mcInfo: McInfo?
    // TODO: relevance
}

struct McPinger {
    static func ping(_ serverAddress: String, completion: @escaping (McInfo?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let mcInfo = McInfo.forServerAddress(serverAddress)
            print("\(mcInfo!)")
            completion(mcInfo)
        }
    }
}

func convertBase64StringToImage(imageBase64String: String) -> UIImage {
    let imageData = Data.init(base64Encoded: imageBase64String)
    let image = UIImage(data: imageData!)
    return image!
}

struct McpingWidgetExtensionEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        if let mcInfo = entry.mcInfo {
            ZStack {
                Image("minecraft-dirt").interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fill)
                Rectangle().opacity(0.6)
                Image(uiImage: convertBase64StringToImage(imageBase64String: mcInfo.favicon!)).interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fit).shadow(color: .black, radius: 30)
                VStack(alignment: .leading) {
                    Spacer()
                    ZStack {
                        Rectangle().opacity(0.6).frame(height: 50)
                        VStack(alignment: .leading) {
                            Text(entry.configuration.serverAddress ?? "mc.hypixel.net").foregroundColor(.white).font(.custom("minecraft", size: 12)).shadow(color: .black, radius: 1, x: 1, y: 1)
                            Spacer().frame(height: 3)
                            Text("\(mcInfo.players.online) / \(mcInfo.players.max)").foregroundColor(.white).font(.custom("minecraft", size: 12)).shadow(color: .black, radius: 1, x: 1, y: 1)
                        }
                    }
                    Spacer().frame(height: 12)
                }
            }
        } else {
            Text("I do not have mcinfo")
        }
    }
}

@main
struct McpingWidgetExtension: Widget {
    let kind: String = "McpingWidgetViewExtension"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            McpingWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Minecraft Server Info")
        .description("Displays information about a Minecraft server")
    }
}

struct McpingWidgetExtension_Previews: PreviewProvider {
    static var previews: some View {
        McpingWidgetExtensionEntryView(entry: McServerStatusEntry(date: Date(), configuration: ConfigurationIntent(), mcInfo: previewData[0]))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
