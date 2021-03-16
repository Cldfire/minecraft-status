//

import Foundation
import SwiftUI

let sharedContainer: URL = {
    // Write to shared app group container so both the widget and the host app can access
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.cldfire.minecraft-status")!
}()

/// Represents the server status we were able to determine
enum ServerStatus {
    /// The server was online, and we got the given info
    case online(OnlineResponse)
    /// The server was unreachable, but we were able to reach it at some point in the past.
    ///
    /// We may have a cached favicon to make use of.
    case offline(OfflineResponse)
    /// The server was unreachable, and we've never reached it in the past.
    case unreachable(UnreachableResponse)

    /// Attempt to ping the server at the given address.
    static func forServerAddress(_ serverAddress: String) -> Self {
        let status = get_server_status(serverAddress, sharedContainer.path)

        defer {
            free_status_response(status)
        }

        switch status.tag {
        case Online:
            return .online(OnlineResponse(mcInfo: McInfo(status.online.mcinfo)))
        case Offline:
            let cachedFavicon: String?
            if let faviconCstr = status.offline.favicon {
                cachedFavicon = String(cString: faviconCstr)
            } else {
                cachedFavicon = nil
            }

            return .offline(OfflineResponse(favicon: cachedFavicon))
        case Unreachable:
            let errorString: String
            if let errorStringCstr = status.unreachable.error_string {
                errorString = String(cString: errorStringCstr)
            } else {
                errorString = ""
            }

            return .unreachable(UnreachableResponse(errorString: errorString))
        default:
            fatalError("unexpected type of server status response")
        }
    }

    func favicon() -> String? {
        switch self {
        case let .online(response):
            return response.mcInfo.favicon
        case let .offline(response):
            return response.favicon
        case .unreachable:
            return nil
        }
    }

    // We return a Text view here so the resulting string has separators in the numbers
    func playersOnlineText() -> Text {
        switch self {
        case let .online(response):
            return Text("\(response.mcInfo.players.online) / \(response.mcInfo.players.max)")
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

struct OnlineResponse {
    var mcInfo: McInfo
}

struct OfflineResponse {
    /// The server icon (a Base64-encoded PNG image)
    var favicon: String?
}

struct UnreachableResponse {
    var errorString: String
}

struct McInfo {
    /// Latency to the server
    var latency: UInt64
    var version: Version
    /// Information about online players
    var players: Players
    /// The server's description text
    var description: String
    /// The server icon (a Base64-encoded PNG image)
    var favicon: String?
}

// Using a separate extension for this initializer keeps the default memberwise initializer
// around
extension McInfo {
    /// Copies data from the given `McInfoRaw` in order to create this struct.
    init(_ from: McInfoRaw) {
        self.latency = from.latency

        self.version = Version(from.version)
        self.players = Players(from.players)

        if let descriptionCstr = from.description {
            self.description = String(cString: descriptionCstr)
        } else {
            self.description = ""
        }

        if let faviconCstr = from.favicon {
            self.favicon = String(cString: faviconCstr)
        } else {
            self.favicon = nil
        }
    }
}

struct Version {
    var name: String
    var protocolVersion: Int64
}

extension Version {
    /// Copies data from the given `VersionRaw` in order to create this struct.
    init(_ from: VersionRaw) {
        if let nameCstr = from.name {
            self.name = String(cString: nameCstr)
        } else {
            self.name = ""
        }

        self.protocolVersion = from.protocol
    }
}

struct Player {
    var name: String
    var id: String
}

extension Player {
    /// Copies data from the given `PlayerRaw` in order to create this struct.
    init(_ from: PlayerRaw) {
        if let nameCstr = from.name {
            self.name = String(cString: nameCstr)
        } else {
            self.name = ""
        }

        if let idCstr = from.id {
            self.id = String(cString: idCstr)
        } else {
            self.id = ""
        }
    }
}

struct Players {
    var max: Int64
    var online: Int64
    var sample: [Player]
}

extension Players {
    /// Copies data from the given `PlayersRaw` in order to create this struct.
    init(_ from: PlayersRaw) {
        self.max = from.max
        self.online = from.online

        self.sample = [Player]()
        self.sample.reserveCapacity(Int(from.sample_len))

        for i in 0..<from.sample_len {
            self.sample.append(Player(from.sample[Int(i)]))
        }
    }
}
