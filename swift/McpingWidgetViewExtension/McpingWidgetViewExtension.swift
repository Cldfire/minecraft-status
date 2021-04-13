//

import Intents
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
    func placeholder(in _: Context) -> McServerStatusEntry {
        previewData[0]
    }

    func getSnapshot(for _: ConfigurationIntent, in _: Context, completion: @escaping (McServerStatusEntry) -> Void) {
        // Preview uses a ping response from mc.hypixel.net
        let entry = previewData[2]
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let protocolType = protocolTypeFromConfig(configuration.protocolTypeConfig)

        McPinger.ping(configuration.serverAddress ?? "", protocolType: protocolType) { serverStatus in
            let entry = McServerStatusEntry(date: currentDate, configuration: configuration, status: serverStatus)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct McServerStatusEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let status: ServerStatus
    // TODO: relevance
}

enum McPinger {
    static func ping(_ serverAddress: String, protocolType: ProtocolType, completion: @escaping (ServerStatus) -> Void) {
        // TODO: not sure that this is the correct way of making a backgroud network request
        // in a widget
        DispatchQueue.global(qos: .background).async {
            let status = ServerStatus.forServerAddress(serverAddress, protocolType: protocolType)
            completion(status)
        }
    }
}

func protocolTypeFromConfig(_ protocolTypeConfig: ProtocolTypeConfig) -> ProtocolType {
    switch protocolTypeConfig {
    case .auto:
        return Auto
    case .java:
        return Java
    case .bedrock:
        return Bedrock
    case .unknown:
        return Auto
    }
}

/// Attempts to convert a maybe-present base64 image string into a `UIImage`.
func convertBase64StringToImage(imageBase64String: String?) -> UIImage? {
    guard let imageString = imageBase64String else {
        return nil
    }

    guard let imageData = Data(base64Encoded: imageString) else {
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

struct ServerFavicon: View {
    let faviconString: String?

    var body: some View {
        // The backing images
        Image("minecraft-dirt").interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fill).unredacted()
        Rectangle().opacity(0.65)

        // TODO: what do we do if there's no server icon?
        if let favicon = convertBase64StringToImage(imageBase64String: faviconString) {
            Image(uiImage: favicon).interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fit).shadow(radius: 30)
        }
    }
}

struct McpingWidgetExtensionEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if case .unreachable = entry.status {
            if let serverAddress = entry.configuration.serverAddress, !serverAddress.isEmpty {
                Text("Unable to ping Minecraft server at address \"\(serverAddress)\"").padding()
            } else {
                Text("No server address specified, please edit the widget").padding()
            }
        } else {
            ZStack {
                ServerFavicon(faviconString: entry.status.favicon())

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

                            // Players online and status indicator
                            HStack(spacing: 5) {
                                entry.status.playersOnlineText().foregroundColor(.white).font(.custom("minecraft", size: 12)).shadow(color: .black, radius: 0.5, x: 1, y: 1).minimumScaleFactor(0.8).lineLimit(1)

                                Circle().foregroundColor(entry.status.statusColor()).fixedSize().scaleEffect(0.9)
                            }
                        }.frame(maxWidth: .infinity).padding(.leading, 10).padding(.trailing, 10)
                    }.frame(height: 45)

                    // This spacer separates the banner from the bottom of the widget
                    Spacer()
                }
            }.colorScheme(.light) // Force the light colorscheme to keep the translucent banner black
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

            McpingWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted Dark Mode")
        }
    }
}
