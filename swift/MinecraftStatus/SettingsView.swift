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
        MinecraftStatusApp.fullVersion
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
            item.imageName.imageForName()
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
        case let .openUrl(url):
            UIApplication.shared.open(url)
        case let .shareUrl(url):
            present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
        }
    }
}

enum ImageName {
    case system(String)
    case asset(String)

    func imageForName() -> Image {
        switch self {
        case let .system(name):
            return Image(systemName: name)
        case let .asset(name):
            return Image(name)
        }
    }
}

func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
    guard var topController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

    while let presentedViewController = topController.presentedViewController {
        topController = presentedViewController
    }

    // TODO: temporary fix so this doesn't crash on iPads, make this better
    let popover = viewController.popoverPresentationController
    popover?.sourceView = topController.view
    popover?.sourceRect = CGRect(x: 0, y: 0, width: 64, height: 64)

    topController.present(viewController, animated: animated, completion: completion)
}

func widgetHelpURL() -> URL {
    switch UIDevice.current.userInterfaceIdiom {
    case .pad:
        // Link to iPad widget help article
        return URL(string: "https://support.apple.com/en-us/HT211328")!
    default:
        // Link to iPhone widget help article
        return URL(string: "https://support.apple.com/en-us/HT207122")!
    }
}

/// The data for a settings row item.
struct SettingsRowItem: Identifiable {
    var id = UUID()
    var title: String
    var subtitle: String
    var imageName: ImageName
    var color: Color
    var action: SettingsRowItemAction
}

let headerRows = [
    SettingsRowItem(title: "Widget Setup", subtitle: "Learn how to use widgets", imageName: .system("questionmark"), color: .blue, action: .openUrl(widgetHelpURL())),
]

let footerRows = [
    SettingsRowItem(title: "Rate the App", subtitle: "Reviews are greatly appreciated!", imageName: .system("star.fill"), color: .pink, action: .openUrl(URL(string: "itms-apps://apps.apple.com/app/id1549596839?action=write-review")!)),
    SettingsRowItem(title: "Share", subtitle: "Tell your friends!", imageName: .system("square.and.arrow.up"), color: .green, action: .shareUrl(URL(string: "https://apps.apple.com/app/id1549596839")!)),
    SettingsRowItem(title: "Open Source", subtitle: "Contribute and file issues", imageName: .system("swift"), color: .orange, action: .openUrl(URL(string: "https://github.com/Cldfire/minecraft-status")!)),
    SettingsRowItem(title: "@_cldfire", subtitle: "Follow me on Twitter for updates", imageName: .asset("twitterLogoWhite"), color: Color("twitterBlue"), action: .openUrl(URL(string: "https://twitter.com/_cldfire")!)),
]
