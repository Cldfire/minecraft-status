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
        let alwaysUseIdenticon = !(configuration.useServerFavicon as? Bool ?? true)

        McPinger.ping(configuration.serverAddress ?? "", protocolType, alwaysUseIdenticon) { serverStatus in
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
    static func ping(_ serverAddress: String, _ protocolType: ProtocolType, _ alwaysUseIdenticon: Bool, completion: @escaping (ServerStatus) -> Void) {
        // TODO: not sure that this is the correct way of making a backgroud network request
        // in a widget
        DispatchQueue.global(qos: .background).async {
            let status = ServerStatus.forServerAddress(serverAddress, protocolType, alwaysUseIdenticon)
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
    let favicon: Favicon
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if favicon.isGenerated() {
            // Add a background behind generated favicons
            Rectangle().foregroundColor(Color(UIColor.systemBackground))
        } else {
            // Minecraft dirt block backing
            Image("minecraft-dirt").interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fill).unredacted()
            Rectangle().opacity(0.60).foregroundColor(.black)
        }

        if let faviconImage = convertBase64StringToImage(imageBase64String: favicon.faviconString()) {
            Image(uiImage: faviconImage).interpolation(.none).antialiased(false).resizable().aspectRatio(contentMode: .fit).shadow(radius: favicon.isGenerated() ? 0 : 30).colorScheme(.light)
        }
    }
}

struct OverlayBanner: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack {
            // These spacers move the banner towards the bottom of the widget
            Spacer()
            Spacer()
            Spacer()
            Spacer()
            Spacer()

            HStack {
                // The banner content
                VStack(alignment: .leading, spacing: 4) {
                    // Server address
                    Text("\(chooseBestHeaderText(for: entry.configuration))").foregroundColor(.white).shadow(color: .black, radius: 0.5, x: 1, y: 1).lineLimit(1)

                    // Players online and status indicator
                    HStack(spacing: 5) {
                        entry.status.playersOnlineText().foregroundColor(.white).shadow(color: .black, radius: 0.5, x: 1, y: 1).minimumScaleFactor(0.8).lineLimit(1)

                        Circle().foregroundColor(entry.status.statusColor()).fixedSize().scaleEffect(family == .systemLarge ? 1.0 : 0.9)
                    }
                }
                .font(.custom("minecraft", size: family == .systemLarge ? 14 : 12))
                .frame(height: 45, alignment: .leading)
                .frame(maxWidth: family == .systemLarge ? .none : .infinity)
                .padding(.leading, family == .systemLarge ? 20 : 10)
                .padding(.trailing, family == .systemLarge ? 20 : 10)
                .padding(.top, family == .systemLarge ? 5 : 0)
                .padding(.bottom, family == .systemLarge ? 5 : 0)
                .background(
                    Color.black
                        .opacity(0.7)
                        .cornerRadius(family == .systemLarge ? 8 : 0)
                )

                if family == .systemLarge {
                    // Shove the banner to the left side for the large widget
                    Spacer()
                }
            }
            .padding(.leading, family == .systemLarge ? 20 : 0)
            .padding(.trailing, family == .systemLarge ? 100 : 0)

            // This spacer separates the banner from the bottom of the widget
            Spacer()
        }
    }
}

struct MinecraftStatusWidgetExtensionEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if case .unreachable = entry.status {
            if let serverAddress = entry.configuration.serverAddress, !serverAddress.isEmpty {
                Text("Unable to ping Minecraft server \"\(serverAddress)\"").padding()
            } else {
                Text("Please edit the widget and set a server address").padding()
            }
        } else {
            ZStack {
                ServerFavicon(favicon: entry.status.favicon())
                OverlayBanner(entry: entry)
            }
        }
    }
}

@main
struct MinecraftStatusWidgetExtension: Widget {
    let kind: String = "MinecraftStatusWidgetViewExtension"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            MinecraftStatusWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Minecraft Server Icon")
        .description("Information about a Minecraft server on top of its icon")
        // TODO: work on the large widget a bit
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct MinecraftStatusWidgetExtension_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(0..<previewData.count, id: \.self) { i in
                MinecraftStatusWidgetExtensionEntryView(entry: previewData[i])
                    .previewContext(WidgetPreviewContext(family: .systemSmall))
            }

            MinecraftStatusWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")

            MinecraftStatusWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted")

            MinecraftStatusWidgetExtensionEntryView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted Dark Mode")

            ForEach(0..<previewData.count, id: \.self) { i in
                MinecraftStatusWidgetExtensionEntryView(entry: previewData[i])
                    .previewContext(WidgetPreviewContext(family: .systemLarge))
            }
        }
    }
}
