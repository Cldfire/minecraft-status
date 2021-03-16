use std::{
    ffi::CStr,
    fs, mem,
    os::raw::{c_uint, c_ulonglong},
    panic,
    path::Path,
    time::Duration,
};
use std::{
    ffi::CString,
    os::raw::{c_char, c_longlong},
};

use mcping::Response;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ServerStatusError {
    #[error("{0}")]
    McpingError(#[from] mcping::Error),
    #[error("the pointer to the server address string was null")]
    InputPointerNull,
    #[error("{0}")]
    Utf8Error(#[from] std::str::Utf8Error),
    #[error("{0}")]
    IoError(#[from] std::io::Error),
    #[error("{0}")]
    JsonError(#[from] serde_json::Error),
    #[error("a panic occurred in rust")]
    PanicOccurred,
    #[error("the given server address string was empty")]
    EmptyServerAddress,
}

/// The overall status response.
#[repr(C)]
pub enum ServerStatus {
    /// The server was online and we got a valid ping response.
    Online(OnlineResponse),
    /// The server was offline and couldn't be reached, but we've been able to
    /// get a valid response from it before.
    ///
    /// This struct contains cached data.
    Offline(OfflineResponse),
    /// The server was offline and couldn't be reached, and we've never gotten
    /// a response from it previously.
    ///
    /// This struct contains an error message string and also ends up being a
    /// bit of a catch-all for any errors that can occur. In the future it could
    /// be nice to break this up into finer-grained variants (one for a legit
    /// error and one for the common case of an invalid server address).
    Unreachable(UnreachableResponse),
}

#[repr(C)]
pub struct OnlineResponse {
    /// The data obtained from the server's ping response.
    pub mcinfo: McInfoRaw,
}

#[repr(C)]
pub struct OfflineResponse {
    /// The last seen icon this server was using (a Base64-encoded PNG image).
    ///
    /// This will be a null pointer if the server didn't have an icon.
    pub favicon: *mut c_char,
}

#[repr(C)]
pub struct UnreachableResponse {
    /// An error string describing why the server wasn't reachable.
    pub error_string: *mut c_char,
}

/// Represents the format in which a favicon is cached on-disk.
#[derive(Debug, Default, Serialize, Deserialize)]
struct CachedFavicon {
    favicon: Option<String>,
}

/// The server status response
#[repr(C)]
#[derive(Debug)]
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
    /// Build this struct from a server's ping response data.
    fn new(latency: u64, status: Response) -> Self {
        let description = CString::new(status.description.text()).unwrap();
        let favicon = status
            .favicon
            .as_deref()
            .map(process_favicon)
            .map(CString::new)
            .unwrap();

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
/// Trim off the non-base64 part of the favicon string to make it easier to get
/// an image in Swift land.
fn process_favicon(favicon: &str) -> &str {
    favicon.trim_start_matches("data:image/png;base64,")
}

/// Information about the server's version
#[repr(C)]
#[derive(Debug)]
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
#[derive(Debug)]
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
#[derive(Debug)]
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

/// The rusty version of what we need to get done.
///
/// The main logic of pinging a server and caching / processing the relevant data
/// should be implemented here. It's perfectly okay to panic and return errors as
/// needed.
fn get_server_status_rust(
    address: &str,
    app_group_container: &str,
) -> Result<ServerStatus, ServerStatusError> {
    if address.is_empty() {
        // The following logic is meaningless if the server address is a blank
        // string
        return Err(ServerStatusError::EmptyServerAddress);
    }

    // Data for a specific server is stored within a folder specifically for
    // ping data, and within that a folder specifically for the address being
    // pinged.
    //
    // Note that the port will be a part of this address, so this will properly
    // handle multiple servers with the same IP / hostname but differing ports.
    // The server address is lowercased for optimal cache hits. It will not
    // handle unifying `mc.server.net` and `mc.server.net:25565`, though.
    let server_folder = Path::new(app_group_container)
        .join("mc_server_data")
        .join(address.to_lowercase());
    // Make sure the folders have been created
    fs::create_dir_all(&server_folder)?;

    let cached_favicon_path = server_folder.join("cached_favicon");

    // A five-second timeout is used to avoid exceeding the amount of time our
    // widget process is given to run in.
    //
    // For example, this will end an attempt to ping "google.com" in about five
    // seconds; otherwise, we'd wait until the OS timed out the request, before
    // which time our process would likely end up being killed. This would
    // result in the widget being left in the placeholder view rather than
    // being updated with an error message.
    match mcping::get_status(address, Duration::from_secs(5)) {
        Ok((latency, status)) => {
            // Cache the favicon
            let cached_favicon = CachedFavicon {
                favicon: status
                    .favicon
                    .as_deref()
                    .map(process_favicon)
                    .map(|s| s.to_owned()),
            };
            let cached_favicon = serde_json::to_string(&cached_favicon)?;
            fs::write(&cached_favicon_path, &cached_favicon)?;

            let mcinfo = McInfoRaw::new(latency, status);
            Ok(ServerStatus::Online(OnlineResponse { mcinfo }))
        }
        Err(e) => {
            if cached_favicon_path.exists() {
                let data = fs::read(&cached_favicon_path)?;
                let cached_favicon: CachedFavicon = serde_json::from_slice(&data)?;

                let favicon = if let Some(favicon) = cached_favicon.favicon {
                    let favicon = CString::new(favicon).unwrap();
                    favicon.into_raw()
                } else {
                    std::ptr::null_mut()
                };

                Ok(ServerStatus::Offline(OfflineResponse { favicon }))
            } else {
                Err(e)?
            }
        }
    }
}

/// This function is responsible for catching any panics that could possibly
/// occur.
fn get_server_status_catch_panic(
    address: *const c_char,
    app_group_container: *const c_char,
) -> Result<ServerStatus, ServerStatusError> {
    match panic::catch_unwind(|| {
        if address.is_null() {
            return Err(ServerStatusError::InputPointerNull);
        }

        let address = unsafe { CStr::from_ptr(address) };
        let address = address.to_str()?;

        if app_group_container.is_null() {
            return Err(ServerStatusError::InputPointerNull);
        }

        let app_group_container = unsafe { CStr::from_ptr(app_group_container) };
        let app_group_container = app_group_container.to_str()?;

        get_server_status_rust(address, app_group_container)
    }) {
        Ok(result) => Ok(result?),
        Err(_) => Err(ServerStatusError::PanicOccurred),
    }
}

/// Ping a Minecraft server at the given `address`, working with data stored in
/// the given `app_group_container`.
///
/// # Safety
///
/// The provided pointers must point to valid cstrings.
#[no_mangle]
pub unsafe extern "C" fn get_server_status(
    address: *const c_char,
    app_group_container: *const c_char,
) -> ServerStatus {
    match get_server_status_catch_panic(address, app_group_container) {
        Ok(status) => status,
        Err(e) => {
            // Note that we need to be careful not to panic here
            let error_string = format!("failed to ping server: {}", e);
            let error_string = CString::new(error_string).unwrap_or_default();

            ServerStatus::Unreachable(UnreachableResponse {
                error_string: error_string.into_raw(),
            })
        }
    }
}

#[no_mangle]
pub extern "C" fn free_status_response(response: ServerStatus) {
    match response {
        ServerStatus::Online(OnlineResponse { mcinfo }) => free_mcinfo(mcinfo),
        ServerStatus::Offline(OfflineResponse { favicon }) => {
            if !favicon.is_null() {
                let _ = unsafe { CString::from_raw(favicon) };
            }
        }
        ServerStatus::Unreachable(UnreachableResponse { error_string }) => {
            if !error_string.is_null() {
                let _ = unsafe { CString::from_raw(error_string) };
            }
        }
    }
}

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
