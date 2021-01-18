//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> McServerStatusEntry {
        previewData[0]
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (McServerStatusEntry) -> ()) {
        // Preview uses a ping response from mc.hypixel.net
        let entry = previewData[2]
        completion(entry)
    }
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        // TODO: nicely handle when a server goes offline
        McPinger.ping(configuration.serverAddress ?? "") { mcInfo in
            let entry = McServerStatusEntry(date: currentDate, configuration: configuration, mcInfo: mcInfo)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct McServerStatusEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    // TODO: store error if mc server can't be pinged
    let mcInfo: McInfo?
    // TODO: relevance
}

struct McPinger {
    static func ping(_ serverAddress: String, completion: @escaping (McInfo?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let mcInfo = McInfo.forServerAddress(serverAddress)
            completion(mcInfo)
        }
    }
}

/// Attempts to convert a maybe-present base64 image string into a `UIImage`.
func convertBase64StringToImage(imageBase64String: String?) -> UIImage? {
    guard let imageString = imageBase64String else {
        return nil
    }

    guard let imageData = Data.init(base64Encoded: imageString) else {
        return nil
    }

    return UIImage(data: imageData)
}

func chooseBestHeaderText(for configuration: ConfigurationIntent) -> String {
    if let serverName = configuration.serverName, !serverName.isEmpty {
        return serverName
    } else {
        return configuration.serverAddress ?? ""
    }
}

struct McpingWidgetExtensionEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        if let mcInfo = entry.mcInfo {
            ZStack {
                // The backing images
                Image("minecraft-dirt").interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fill).unredacted()
                Rectangle().opacity(0.65)
                
                // TODO: what do we do if there's no server icon?
                if let favicon = convertBase64StringToImage(imageBase64String: mcInfo.favicon) {
                    Image(uiImage: favicon).interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fit).shadow(radius: 30)
                }
                
                // The banner content
                VStack {
                    // These spacers move the banner towards the bottom of the widget
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    ZStack {
                        // The translucent banner backing (stretches horizontally across the entire widget)
                        Rectangle().opacity(0.7)
                        
                        // The content on top of the banner
                        VStack(alignment: .leading, spacing: 4) {
                            // Server address
                            Text("\(chooseBestHeaderText(for: entry.configuration))").foregroundColor(.white).font(.custom("minecraft", size: 12)).shadow(color: .black, radius: 0.5, x: 1, y: 1).lineLimit(1)
                            
                            // Players online and latency indicator
                            HStack(spacing: 5) {
                                Text("\(mcInfo.players.online) / \(mcInfo.players.max)").foregroundColor(.white).font(.custom("minecraft", size: 12)).shadow(color: .black, radius: 0.5, x: 1, y: 1).minimumScaleFactor(0.8).lineLimit(1)
                                
                                Group {
                                    if mcInfo.latency < 400 {
                                        Circle().foregroundColor(Color.green)
                                    } else if mcInfo.latency < 1000 {
                                        Circle().foregroundColor(Color.orange)
                                    } else {
                                        Circle().foregroundColor(Color.red)
                                    }
                                }.fixedSize().scaleEffect(0.9)
                            }
                        }.frame(maxWidth: .infinity).padding(.leading, 10).padding(.trailing, 10)
                    }.frame(height: 45)
                    
                    // This spacer separates the banner from the bottom of the widget
                    Spacer()
                }
            }.colorScheme(.light) // Force the light colorscheme to keep the translucent banner black
        } else {
            if let serverAddress = entry.configuration.serverAddress, !serverAddress.isEmpty {
                Text("Unable to ping Minecraft server at address \"\(serverAddress)\"").padding()
            } else {
                Text("No server address specified, please edit the widget").padding()
            }
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
        .configurationDisplayName("Minecraft Server Icon")
        .description("Information about a Minecraft server on top of its icon")
        // TODO: work on the large widget a bit
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct McpingWidgetExtension_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(0..<previewData.count, id: \.self) { i in
                McpingWidgetExtensionEntryView(entry: previewData[i])
                    .previewContext(WidgetPreviewContext(family: .systemSmall))
            }
            
            McpingWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")
            
            McpingWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted")
        }
    }
}
