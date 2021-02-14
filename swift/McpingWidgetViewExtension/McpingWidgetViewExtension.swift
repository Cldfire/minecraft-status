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

        McPinger.ping(configuration.serverAddress ?? "") { mcInfo in
            let serverResponse: ServerStatus

            if let mcInfo = mcInfo {
                // Cache the possibly-present favicon
                //
                // We want to write this file even when there's no favicon data to cache
                // so that we can properly represent the offline state for servers that
                // don't have favicons.
                //
                // If we got mcinfo we had to have a serveraddress, so the ! is safe
                let pingData = CachedFavicon(favicon: mcInfo.favicon)
                CodableStore.write(configuration.serverAddress!.lowercased() + ".favicon", pingData)

                serverResponse = .online(mcInfo)
            } else if let serverAddress = configuration.serverAddress, let cachedFavicon: CachedFavicon = CodableStore.read(serverAddress.lowercased() + ".favicon") {
                // Server is unreachable but was previously reachable at this address, treat it as being
                // offline and use the cached favicon if possible
                serverResponse = .offline(cachedFavicon.favicon)
            } else {
                // Server is unreachable and was never previously reachable
                serverResponse = .unreachable
            }

            let entry = McServerStatusEntry(date: currentDate, configuration: configuration, status: serverResponse)
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
    static func ping(_ serverAddress: String, completion: @escaping (McInfo?) -> Void) {
        // TODO: not sure that this is the correct way of making a backgroud network request
        // in a widget
        DispatchQueue.global(qos: .background).async {
            let mcInfo = McInfo.forServerAddress(serverAddress)
            completion(mcInfo)
        }
    }
}

/// Represents the server status we were able to determine
enum ServerStatus {
    /// The server was online, and we got the given info
    case online(McInfo)
    /// The server was unreachable, but we were able to reach it at some point in the past.
    ///
    /// We may have a cached favicon to make use of.
    case offline(String?)
    /// The server was unreachable, and we've never reached it in the past.
    case unreachable

    func favicon() -> String? {
        switch self {
        case let .online(mcInfo):
            return mcInfo.favicon
        case let .offline(fav):
            return fav
        case .unreachable:
            return nil
        }
    }

    // We return a Text view here so the resulting string has separators in the numbers
    func playersOnlineText() -> Text {
        switch self {
        case let .online(mcInfo):
            return Text("\(mcInfo.players.online) / \(mcInfo.players.max)")
        case .offline:
            return Text("-- / --")
        case .unreachable:
            return Text("")
        }
    }

    func statusColor() -> Color {
        if case .online = self {
            // We always return green if the server is online, regardless of latency.
            //
            // This decision was made because latency is oftentimes irregular in the context
            // of a phone widget; for instance, when using data rather than wifi. This
            // irregularity makes latency a poor data point to use to change the status color,
            // and I personally found it more annoying than useful.
            return Color.green
        } else {
            return Color.gray
        }
    }
}

enum CodableStore {
    static let sharedContainer: URL = {
        // Write to shared app group container so both the widget and the host app can access
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.cldfire.minecraft-status")!
    }()

    /// Write the given data to a file of the given name (encoded as JSON)
    static func write<T: Encodable>(_ fileName: String, _ data: T) {
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: self.sharedContainer.appendingPathComponent(fileName))
        } catch {
            print("Error encoding data to file: \(error)")
        }
    }

    /// Read JSON data from the given file of the given name and decode it
    static func read<T: Decodable>(_ fileName: String) -> T? {
        do {
            let encodedData = try Data(contentsOf: sharedContainer.appendingPathComponent(fileName))
            return try JSONDecoder().decode(T.self, from: encodedData)
        } catch {
            print("Error decoding data from file: \(error)")
            return nil
        }
    }
}

/// In-memory representation of the favicon we may have cached on disk.
struct CachedFavicon: Codable {
    let favicon: String?
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
