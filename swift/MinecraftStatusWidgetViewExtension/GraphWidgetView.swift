//

import MinecraftStatusCommon
import SwiftUI
import WidgetKit

struct GraphWidgetView: View {
    var entry: McServerStatusEntry

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            if case .unreachable = entry.status {
                if let serverAddress = entry.configuration.serverAddress, !serverAddress.isEmpty {
                    Text("Unable to ping Minecraft server \"\(serverAddress)\"").padding()
                } else {
                    Text("Please edit the widget and set a server address").padding()
                }
            } else {
                VStack {
                    HStack {
                        // Server address
                        Text("\(chooseBestHeaderText(for: entry.configuration))").font(.custom("minecraft", size: 12)).lineLimit(1)

                        Spacer()

                        // Players online and status indicator
                        HStack(spacing: 5) {
                            entry.status.playersOnlineText().font(.custom("minecraft", size: 12)).minimumScaleFactor(0.8).lineLimit(1)

                            Circle().foregroundColor(entry.status.statusColor()).fixedSize().scaleEffect(0.9)
                        }
                    }.padding(.bottom, 5)

                    Spacer()

                    HStack {
                        ServerFavicon(favicon: entry.status.favicon()).cornerRadius(15.0)

                        Spacer()

                        LayeredBarGraph(data: entry.status.weekStats()!.makeLayeredBarData())
                    }
                }
                .padding()
                .font(.custom("minecraft", size: 12))
            }
        }
    }
}

extension WeekStatsSwift {
    func makeLayeredBarData() -> [LayeredBarData] {
        self.dailyStats.map { stats in
            LayeredBarData(topDataPoint: CGFloat(stats.peak_online) / CGFloat(self.peakMax), bottomDataPoint: CGFloat(stats.average_online) / CGFloat(self.peakMax))
        }
    }
}

struct GraphWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(0..<previewData.count, id: \.self) { i in
                GraphWidgetView(entry: previewData[i])
                    .previewContext(WidgetPreviewContext(family: .systemMedium))
            }

            GraphWidgetView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")

            GraphWidgetView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted")

            GraphWidgetView(entry: previewData[0])
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
                .redacted(reason: .placeholder)
                .previewDisplayName("Redacted Dark Mode")
        }
    }
}
