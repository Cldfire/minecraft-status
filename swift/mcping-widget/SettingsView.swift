// UI design inspired by https://github.com/AnderGoig/github-contributions-ios

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(headerRows) { item in
                        Button(action: { item.action.performAction() }) {
                            SettingsRow(item: item)
                        }
                    }
                }

                Section(footer: footer) {
                    ForEach(footerRows) { item in
                        Button(action: { item.action.performAction() }) {
                            SettingsRow(item: item)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Minecraft Status", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var footer: some View {
        McpingWidgetApp.fullVersion
            .map { Text("version \($0)") }
            .textCase(.uppercase)
            .foregroundColor(.secondary)
            .font(.caption2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowInsets(EdgeInsets(top: 24.0, leading: 0.0, bottom: 24.0, trailing: 0.0))
    }
}

struct SettingsRow: View {
    let item: SettingsRowItem

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Image(systemName: item.systemImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 17.0, height: 17.0)
                .padding(6.0)
                .background(item.color)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6.0, style: .continuous))

            VStack(alignment: .leading, spacing: 3.0) {
                Text(item.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5.0)
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

enum SettingsRowItemAction {
    case openUrl(URL)
    case shareUrl(URL)
    
    func performAction() {
        switch self {
        case .openUrl(let url):
            UIApplication.shared.open(url)
        case .shareUrl(let url):
            present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
        }
    }
}

func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
    guard var topController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

    while let presentedViewController = topController.presentedViewController {
        topController = presentedViewController
    }

    topController.present(viewController, animated: animated, completion: completion)
}

/// The data for a settings row item.
struct SettingsRowItem: Identifiable {
    var id = UUID()
    var title: String
    var subtitle: String
    var systemImageName: String
    var color: Color
    var action: SettingsRowItemAction
}

let headerRows = [
    SettingsRowItem(title: "Widget Setup", subtitle: "Learn how to use widgets", systemImageName: "questionmark", color: .blue, action: .openUrl(URL(string: "https://support.apple.com/en-us/HT207122")!)),
]

let footerRows = [
    SettingsRowItem(title: "Rate the App", subtitle: "Reviews are greatly appreciated!", systemImageName: "star.fill", color: .pink, action: .openUrl(URL(string: "itms-apps://apps.apple.com/app/id1549596839?action=write-review")!)),
    SettingsRowItem(title: "Share", subtitle: "Tell your friends!", systemImageName: "square.and.arrow.up", color: .green, action: .shareUrl(URL(string: "https://apps.apple.com/app/id1549596839")!)),
    SettingsRowItem(title: "Open Source", subtitle: "Contribute and file issues", systemImageName: "swift", color: .orange, action: .openUrl(URL(string: "https://github.com/Cldfire/minecraft-status")!))
]
