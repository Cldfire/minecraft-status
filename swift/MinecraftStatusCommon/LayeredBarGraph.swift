//

import SwiftUI

public struct LayeredBarGraph: View {
    public var data: [LayeredBarData]

    public init(data: [LayeredBarData]) {
        self.data = data
    }

    public var body: some View {
        HStack(spacing: 13) {
            ForEach(data.indices) { i in
                let barData = data[i]
                LayeredBar(data: barData)
            }
        }
    }
}

struct LayeredBar: View {
    var data: LayeredBarData

    var body: some View {
        let spaceBetweenBars = CGFloat(6.0)
        let cornerRadius = CGFloat(2.5)

        let topGradient = LinearGradient(gradient: Gradient(colors: [Color(red: 0.26, green: 0.38, blue: 1.00), Color(red: 0.75, green: 0.35, blue: 1.00)]), startPoint: .top, endPoint: .bottom)
        let bottomGradient = LinearGradient(gradient: Gradient(colors: [Color(red: 0.96, green: 0.28, blue: 0.44), Color(red: 0.99, green: 0.16, blue: 0.71)]), startPoint: .top, endPoint: .bottom)

        VStack {
            ZStack {
                Color(red: 0.93, green: 0.95, blue: 0.99).cornerRadius(cornerRadius).padding(1)
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Take up empty space at the top above the top data point
                        Spacer().frame(width: .infinity, height: geometry.size.height * (1.0 - data.topDataPoint))
                        // The top data point bar
                        topGradient.cornerRadius(cornerRadius).frame(width: .infinity, height: geometry.size.height * (data.topDataPoint - data.bottomDataPoint))
                        // Take up empty space at the top above the top data point
                        Spacer().frame(width: .infinity, height: spaceBetweenBars)
                        // The bottom data point bar
                        bottomGradient.cornerRadius(cornerRadius).frame(width: .infinity, height: geometry.size.height * data.bottomDataPoint - spaceBetweenBars)
                    }
                }
            }.frame(width: 5, height: .infinity)

            if let label = data.label {
                Text(label).font(.system(size: 11.0, design: .monospaced)).fontWeight(.light)
            }
        }
    }
}

public struct LayeredBarData {
    public var topDataPoint: CGFloat
    public var bottomDataPoint: CGFloat
    public var label: String?

    public init(topDataPoint: CGFloat, bottomDataPoint: CGFloat, label: String? = nil) {
        self.topDataPoint = topDataPoint
        self.bottomDataPoint = bottomDataPoint
        self.label = label
    }
}

struct LayeredBarGraph_Previews: PreviewProvider {
    static var previews: some View {
        let layeredBarData = [
            LayeredBarData(topDataPoint: 0.8, bottomDataPoint: 0.5),
            LayeredBarData(topDataPoint: 0.6, bottomDataPoint: 0.4),
            LayeredBarData(topDataPoint: 0.9, bottomDataPoint: 0.3),
            LayeredBarData(topDataPoint: 0.4, bottomDataPoint: 0.3),
            LayeredBarData(topDataPoint: 0.5, bottomDataPoint: 0.33),
            LayeredBarData(topDataPoint: 0.4, bottomDataPoint: 0.2),
            LayeredBarData(topDataPoint: 0.7, bottomDataPoint: 0.45),
            LayeredBarData(topDataPoint: 0.75, bottomDataPoint: 0.66),
        ]

        let layeredBarDataWithLabels = [
            LayeredBarData(topDataPoint: 0.8, bottomDataPoint: 0.5, label: "T"),
            LayeredBarData(topDataPoint: 0.6, bottomDataPoint: 0.4, label: "W"),
            LayeredBarData(topDataPoint: 0.9, bottomDataPoint: 0.3, label: "T"),
            LayeredBarData(topDataPoint: 0.4, bottomDataPoint: 0.3, label: "F"),
            LayeredBarData(topDataPoint: 0.5, bottomDataPoint: 0.33, label: "S"),
            LayeredBarData(topDataPoint: 0.4, bottomDataPoint: 0.2, label: "S"),
            LayeredBarData(topDataPoint: 0.7, bottomDataPoint: 0.45, label: "M"),
            LayeredBarData(topDataPoint: 0.75, bottomDataPoint: 0.66, label: "T"),
        ]

        LayeredBar(data: layeredBarData[0]).previewLayout(PreviewLayout.fixed(width: 10.0, height: 200.0))
        LayeredBarGraph(data: layeredBarData).previewLayout(PreviewLayout.fixed(width: 200.0, height: 150.0))
        LayeredBarGraph(data: layeredBarDataWithLabels).previewLayout(PreviewLayout.fixed(width: 200.0, height: 150.0))
        LayeredBarGraph(data: layeredBarData).previewLayout(PreviewLayout.fixed(width: 400.0, height: 300.0))
    }
}
