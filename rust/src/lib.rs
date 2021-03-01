use std::{
    ffi::CStr,
    mem,
    os::raw::{c_uint, c_ulonglong},
    panic,
    time::Duration,
};
use std::{
    ffi::CString,
    os::raw::{c_char, c_longlong},
};

use mcping::Response;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum McInfoError {
    #[error("{0}")]
    McpingError(#[from] mcping::Error),
    #[error("the pointer to the server address string was null")]
    AddressPointerNull,
    #[error("{0}")]
    Utf8Error(#[from] std::str::Utf8Error),
    #[error("a panic occurred in rust")]
    PanicOccurred,
}

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

/// This function catches any panics that could possibly occur.
fn get_server_status_rust(address: *const c_char) -> Result<McInfoRaw, McInfoError> {
    if address.is_null() {
        return Err(McInfoError::AddressPointerNull);
    }

    let address = unsafe { CStr::from_ptr(address) };
    let address = address.to_str()?;

    match panic::catch_unwind(|| -> Result<_, McInfoError> {
        let (latency, status) = mcping::get_status(address, Duration::from_secs(5))?;
        Ok(McInfoRaw::new(latency, status))
    }) {
        Ok(result) => result,
        Err(_) => Err(McInfoError::PanicOccurred),
    }
}

/// Ping a Minecraft server at the given `address`.
///
/// Returns 1 if successful and 0 if an error occurred. `out` will only be set
/// if the call was successful.
///
/// # Safety
///
/// The provided pointers must be valid.
#[no_mangle]
pub unsafe extern "C" fn get_server_status(address: *const c_char, out: *mut McInfoRaw) -> i32 {
    match get_server_status_rust(address) {
        Ok(mcinfo) => {
            if !out.is_null() {
                *out = mcinfo;
            }
            1
        }
        Err(_) => 0,
    }
}

/// Free the info object returned by `get_server_status`
#[no_mangle]
pub extern "C" fn free_mcinfo(mcinfo: McInfoRaw) {
    let _ = unsafe { CString::from_raw(mcinfo.description) };

    if !mcinfo.favicon.is_null() {
        let _ = unsafe { CString::from_raw(mcinfo.favicon) };
    }

    let _ = unsafe { CString::from_raw(mcinfo.version.name) };

    if !mcinfo.players.sample.is_null() {
        let sample = unsafe {
            Vec::from_raw_parts(
                mcinfo.players.sample,
                mcinfo.players.sample_len as _,
                mcinfo.players.sample_len as _,
            )
        };

        for player in sample.iter() {
            let _ = unsafe { CString::from_raw(player.name) };
            let _ = unsafe { CString::from_raw(player.id) };
        }
    }
}
