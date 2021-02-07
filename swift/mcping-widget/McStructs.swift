// 

import Foundation

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
    ///
    /// The given `McInfoRaw` will be freed after initialization is finished, regardless of whether or not
    /// it was successful.
    init?(_ from: McInfoRaw) {
        defer {
            free_mcinfo(from)
        }

        self.latency = from.latency

        guard let version = Version(from.version) else {
            return nil
        }
        self.version = version

        guard let players = Players(from.players) else {
            return nil
        }
        self.players = players

        if let descriptionCstr = from.description {
            self.description = String.init(cString: descriptionCstr)
        } else {
            self.description = ""
        }

        if let faviconCstr = from.favicon {
            self.favicon = String.init(cString: faviconCstr)
        } else {
            self.favicon = nil
        }
    }

    static func forServerAddress(_ serverAddress: String) -> McInfo? {
        let rawInfo = UnsafeMutablePointer<McInfoRaw>.allocate(capacity: 1)

        let info: McInfo?
        if get_server_status(serverAddress, rawInfo) == 1 {
            info = McInfo(rawInfo.pointee)
        } else {
            info = nil
        }

        rawInfo.deallocate()
        return info
    }
}

struct Version {
    var name: String
    var protocolVersion: Int64
}

extension Version {
    /// Copies data from the given `VersionRaw` in order to create this struct.
    init?(_ from: VersionRaw) {
        if let nameCstr = from.name {
            self.name = String.init(cString: nameCstr)
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
    init?(_ from: PlayerRaw) {
        if let nameCstr = from.name {
            self.name = String.init(cString: nameCstr)
        } else {
            self.name = ""
        }

        if let idCstr = from.id {
            self.id = String.init(cString: idCstr)
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
    init?(_ from: PlayersRaw) {
        self.max = from.max
        self.online = from.online

        self.sample = [Player]()
        self.sample.reserveCapacity(Int(from.sample_len))

        for i in 0..<from.sample_len {
            guard let player = Player(from.sample[Int(i)]) else {
                return nil
            }
            self.sample.append(player)
        }
    }
}
