use std::{
    ffi::CStr,
    mem,
    os::raw::{c_uint, c_ulonglong},
};
use std::{
    ffi::CString,
    os::raw::{c_char, c_longlong},
};

use mcping::Response;

/// The server status response
#[repr(C)]
pub struct McInfoRaw {
    /// Latency to the server
    pub latency: c_ulonglong,
    pub version: VersionRaw,
    /// Information about online players
    pub players: PlayersRaw,
    /// The server's description text
    pub description: *mut c_char,
    /// The server icon (a Base64-encoded PNG image)
    ///
    /// This will be a null pointer if the server didn't have an icon.
    pub favicon: *mut c_char,
}

impl McInfoRaw {
    fn new(latency: u64, status: Response) -> Self {
        let description = CString::new(status.description.text()).unwrap();
        let favicon = status
            .favicon
            // Trim off the non-base64 part of the string to make it easier to get
            // an image in Swift land
            .map(|s| CString::new(s.trim_start_matches("data:image/png;base64,")).unwrap());

        Self {
            latency,
            version: VersionRaw::from(status.version),
            players: PlayersRaw::from(status.players),
            description: description.into_raw(),
            favicon: favicon
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
        }
    }
}

/// Information about the server's version
#[repr(C)]
pub struct VersionRaw {
    /// The name of the version the server is running
    ///
    /// In practice this comes in a large variety of different formats.
    pub name: *mut c_char,
    /// See https://wiki.vg/Protocol_version_numbers
    pub protocol: c_longlong,
}

impl From<mcping::Version> for VersionRaw {
    fn from(version: mcping::Version) -> Self {
        let name = CString::new(version.name).unwrap();
        Self {
            name: name.into_raw(),
            protocol: version.protocol,
        }
    }
}

#[repr(C)]
pub struct PlayerRaw {
    /// The player's name
    pub name: *mut c_char,
    /// The player's UUID
    pub id: *mut c_char,
}

impl From<mcping::Player> for PlayerRaw {
    fn from(player: mcping::Player) -> Self {
        let name = CString::new(player.name).unwrap();
        let id = CString::new(player.id).unwrap();
        Self {
            name: name.into_raw(),
            id: id.into_raw(),
        }
    }
}

#[repr(C)]
pub struct PlayersRaw {
    pub max: c_longlong,
    pub online: c_longlong,
    /// A preview of which players are online
    ///
    /// In practice servers often don't send this or use it for more advertising.
    /// This will be a null pointer if not present.
    pub sample: *mut PlayerRaw,
    pub sample_len: c_uint,
}

impl From<mcping::Players> for PlayersRaw {
    fn from(players: mcping::Players) -> Self {
        let (sample, sample_len) = if let Some(sample) = players.sample {
            // Map into a vector of our repr(C) `Player` struct
            let mut sample = sample.into_iter().map(PlayerRaw::from).collect::<Vec<_>>();
            sample.shrink_to_fit();
            assert!(sample.len() == sample.capacity());
            let ptr = sample.as_mut_ptr();
            let len = sample.len();

            mem::forget(sample);

            (ptr, len)
        } else {
            (std::ptr::null_mut(), 0)
        };

        Self {
            max: players.max,
            online: players.online,
            sample,
            sample_len: sample_len as _,
        }
    }
}

/// Ping a Minecraft server
#[no_mangle]
pub extern "C" fn get_server_status(address: *const c_char) -> McInfoRaw {
    let address = unsafe { CStr::from_ptr(address) };
    let address = address.to_str().unwrap();

    let (latency, status) = mcping::get_status(&address).unwrap();
    McInfoRaw::new(latency, status)
}

/// Free the info object returned by `get_server_status`
#[no_mangle]
pub extern "C" fn free_mcinfo(mc_info: McInfoRaw) {
    let _ = unsafe { CString::from_raw(mc_info.description) };

    if !mc_info.favicon.is_null() {
        let _ = unsafe { CString::from_raw(mc_info.favicon) };
    }

    let _ = unsafe { CString::from_raw(mc_info.version.name) };

    if !mc_info.players.sample.is_null() {
        let sample = unsafe {
            Vec::from_raw_parts(
                mc_info.players.sample,
                mc_info.players.sample_len as _,
                mc_info.players.sample_len as _,
            )
        };

        for player in sample.iter() {
            let _ = unsafe { CString::from_raw(player.name) };
            let _ = unsafe { CString::from_raw(player.id) };
        }
    }
}
