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

        if let description_cstr = from.description {
            self.description = String.init(cString: description_cstr)
        } else {
            self.description = ""
        }

        if let favicon_cstr = from.favicon {
            self.favicon = String.init(cString: favicon_cstr)
        } else {
            self.favicon = nil
        }
    }
}

struct Version {
    var name: String
    var protocol_version: Int64
    
    /// Copies data from the given `VersionRaw` in order to create this struct.
    init?(_ from: VersionRaw) {
        if let name_cstr = from.name {
            self.name = String.init(cString: name_cstr)
        } else {
            self.name = ""
        }

        self.protocol_version = from.protocol
    }
}

struct Player {
    var name: String
    var id: String
    
    /// Copies data from the given `PlayerRaw` in order to create this struct.
    init?(_ from: PlayerRaw) {
        if let name_cstr = from.name {
            self.name = String.init(cString: name_cstr)
        } else {
            self.name = ""
        }

        if let id_cstr = from.id {
            self.id = String.init(cString: id_cstr)
        } else {
            self.id = ""
        }
    }
}

struct Players {
    var max: Int64
    var online: Int64
    var sample: [Player]
    
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
