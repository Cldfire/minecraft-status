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

use anyhow::{anyhow, Context};
use identicon::{make_base64_identicon, IdenticonInput};
use mcping_common::{Player, Players, ProtocolType, Response, Version};
use serde::{Deserialize, Serialize};
use week_stats::{determine_week_stats, WeekStats};

pub mod identicon;
pub mod mcping_common;
#[cfg(test)]
mod tests;
mod week_stats;

/// The overall status response.
#[repr(C)]
#[derive(Debug)]
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

impl std::fmt::Display for ServerStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ServerStatus::Online(r) => f.write_fmt(format_args!("Online: {}", r)),
            ServerStatus::Offline(r) => f.write_fmt(format_args!("Offline: {}", r)),
            ServerStatus::Unreachable(_) => f.write_str("Unreachable"),
        }
    }
}

#[repr(C)]
#[derive(Debug)]
pub struct OnlineResponse {
    /// The data obtained from the server's ping response.
    pub mcinfo: McInfoRaw,
    /// Statistics about the server over the past week or so.
    pub week_stats: WeekStats,
}

impl std::fmt::Display for OnlineResponse {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("{}", self.mcinfo))
    }
}

#[repr(C)]
#[derive(Debug)]
pub struct OfflineResponse {
    /// The server's favicon (a cached copy or generated favicon).
    pub favicon: FaviconRaw,
    /// Statistics about the server over the past week or so.
    pub week_stats: WeekStats,
}

impl std::fmt::Display for OfflineResponse {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("{}", self.favicon))
    }
}

#[repr(C)]
#[derive(Debug)]
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
    /// The protocol type of the successful ping.
    pub protocol_type: ProtocolType,
    /// Latency to the server
    pub latency: c_ulonglong,
    pub version: VersionRaw,
    /// Information about online players
    pub players: PlayersRaw,
    /// The server's description text
    pub description: *mut c_char,
    /// The server's favicon.
    pub favicon: FaviconRaw,
}

impl std::fmt::Display for McInfoRaw {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("McInfoRaw")
            .field("protocol_type", &self.protocol_type)
            .field("favicon", &format!("{}", self.favicon))
            .finish()
    }
}

impl McInfoRaw {
    /// Build this struct from a server's ping response data and some data to build
    /// and identicon from if necessary.
    fn new(status: Response, identicon_input: IdenticonInput, always_use_identicon: bool) -> Self {
        let description = CString::new(status.motd).unwrap();
        let favicon = FaviconRaw::from_data_and_options(
            status.favicon.as_deref(),
            identicon_input,
            always_use_identicon,
        );

        Self {
            protocol_type: status.protocol_type,
            latency: status.latency,
            version: VersionRaw::from(status.version),
            players: PlayersRaw::from(status.players),
            description: description.into_raw(),
            favicon,
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

impl From<Version> for VersionRaw {
    fn from(version: Version) -> Self {
        let name = CString::new(version.name).unwrap();
        Self {
            name: name.into_raw(),
            protocol: version.protocol.unwrap_or_default(),
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

impl From<Player> for PlayerRaw {
    fn from(player: Player) -> Self {
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

impl From<Players> for PlayersRaw {
    fn from(players: Players) -> Self {
        let (sample, sample_len) = if !players.sample.is_empty() {
            // Map into a vector of our repr(C) `Player` struct
            let mut sample = players
                .sample
                .into_iter()
                .map(PlayerRaw::from)
                .collect::<Vec<_>>();
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

/// The server's favicon image.
#[repr(C)]
#[derive(Debug)]
pub enum FaviconRaw {
    /// The server provided a favicon.
    ServerProvided(*mut c_char),
    /// We generated a favicon because the server didn't provide one.
    Generated(*mut c_char),
    /// There is no favicon image.
    NoFavicon,
}

impl std::fmt::Display for FaviconRaw {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            FaviconRaw::ServerProvided(_) => f.write_str("ServerProvided"),
            FaviconRaw::Generated(_) => f.write_str("Generated"),
            FaviconRaw::NoFavicon => f.write_str("NoFavicon"),
        }
    }
}

impl FaviconRaw {
    /// Picks the best favicon based on the given data and options.
    fn from_data_and_options(
        server_favicon: Option<&str>,
        identicon_input: IdenticonInput,
        always_use_identicon: bool,
    ) -> Self {
        let make_generated = || {
            make_base64_identicon(identicon_input)
                .and_then(|s| CString::new(s).ok())
                .map(|s| Self::Generated(s.into_raw()))
                .unwrap_or(Self::NoFavicon)
        };

        if always_use_identicon {
            // Always generate an identicon
            make_generated()
        } else {
            // Try to use the server favicon and fallback to a generated identicon
            server_favicon
                .map(process_favicon)
                .and_then(|s| CString::new(s).ok())
                .map(|s| Self::ServerProvided(s.into_raw()))
                .unwrap_or_else(make_generated)
        }
    }
}

/// Wrapper around `mcping_common::get_status`.
///
/// This wrapper enables both offline and online testing.
fn mcping_get_status_wrapper(
    address: String,
    timeout: Option<Duration>,
    protocol_type: ProtocolType,
) -> Result<Response, mcping::Error> {
    // Mock some responses for use during testing
    #[cfg(test)]
    {
        let mut response = Response {
            protocol_type: mcping_common::ProtocolType::Java,
            latency: 63,
            version: Version {
                name: "".to_string(),
                protocol: Some(187),
            },
            players: Players {
                max: 200,
                online: 103,
                sample: vec![],
            },
            motd: "".to_string(),
            favicon: None,
        };

        match address.as_str() {
            "test.server.basic" => return Ok(response),
            "test.server.full" => {
                response.version.name = "something".to_string();
                response.motd = "hello! description test".to_string();
                response.favicon = Some("abase64string".to_string());
                response.players.sample = vec![
                    Player {
                        id: "1".to_string(),
                        name: "test1".to_string(),
                    },
                    Player {
                        id: "2".to_string(),
                        name: "test2".to_string(),
                    },
                ];

                return Ok(response);
            }
            "test.server.dnslookupfails" => return Err(mcping::Error::DnsLookupFailed),
            _ => {
                // panic if online testing isn't enabled
                if cfg!(not(feature = "online")) {
                    panic!("can only use mocked addresses while testing offline")
                }
            }
        }
    }

    mcping_common::get_status(address, timeout, protocol_type)
}

/// The rusty version of what we need to get done.
///
/// The main logic of pinging a server and caching / processing the relevant data
/// should be implemented here. It's perfectly okay to panic and return errors as
/// needed.
fn get_server_status_rust(
    address: &str,
    protocol_type: ProtocolType,
    always_use_identicon: bool,
    app_group_container: &str,
) -> Result<ServerStatus, anyhow::Error> {
    if address.is_empty() {
        // The following logic is meaningless if the server address is a blank
        // string
        return Err(anyhow!("empty server address"));
    }

    if app_group_container.is_empty() {
        // The following logic is meaningless if the app group container path
        // is blank
        return Err(anyhow!("empty app group container path"));
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
        .join(format!(
            "{}_{}",
            address.to_lowercase().replace('.', "_").replace(':', "_"),
            protocol_type
        ));
    // Make sure the folders have been created
    fs::create_dir_all(&server_folder).with_context(|| {
        format!(
            "creating server folder(s): {}",
            server_folder.to_string_lossy()
        )
    })?;

    let cached_favicon_path = server_folder.join("cached_favicon");
    let week_stats_path = server_folder.join("week_stats");
    // Drop `server_folder` so we don't accidentally use it again
    drop(server_folder);

    // Prepare the data to create identicons with if necessary
    let identicon_input = IdenticonInput {
        protocol_type,
        address,
    };

    // A five-second timeout is used to avoid exceeding the amount of time our
    // widget process is given to run in.
    //
    // For example, this will end an attempt to ping "google.com" in about five
    // seconds; otherwise, we'd wait until the OS timed out the request, before
    // which time our process would likely end up being killed. This would
    // result in the widget being left in the placeholder view rather than
    // being updated with an error message.
    match mcping_get_status_wrapper(
        address.to_string(),
        Some(Duration::from_secs(5)),
        protocol_type,
    ) {
        Ok(status) => {
            // Cache the favicon
            let cached_favicon = CachedFavicon {
                favicon: status
                    .favicon
                    .as_deref()
                    .map(process_favicon)
                    .map(|s| s.to_owned()),
            };
            let cached_favicon = serde_json::to_string(&cached_favicon)?;
            fs::write(&cached_favicon_path, &cached_favicon).with_context(|| {
                format!(
                    "writing cached favicon struct to {}",
                    cached_favicon_path.to_string_lossy()
                )
            })?;

            // Handle week stats
            let week_stats =
                determine_week_stats(&week_stats_path, status.players.online, status.players.max)?;

            let mcinfo = McInfoRaw::new(status, identicon_input, always_use_identicon);
            Ok(ServerStatus::Online(OnlineResponse { mcinfo, week_stats }))
        }
        Err(e) => {
            if cached_favicon_path.exists() {
                let data = fs::read(&cached_favicon_path).with_context(|| {
                    format!(
                        "reading cached favicon data from {}",
                        cached_favicon_path.to_string_lossy()
                    )
                })?;
                let cached_favicon: CachedFavicon =
                    serde_json::from_slice(&data).with_context(|| {
                        format!(
                            "deserializing cached favicon data: {}",
                            String::from_utf8(data).unwrap_or_else(|_| "invalid utf-8".to_string())
                        )
                    })?;

                let favicon = FaviconRaw::from_data_and_options(
                    cached_favicon.favicon.as_deref(),
                    identicon_input,
                    always_use_identicon,
                );

                // Handle week stats (server is offline, so just use zeroes)
                let week_stats = determine_week_stats(&week_stats_path, 0, 0)?;

                Ok(ServerStatus::Offline(OfflineResponse {
                    favicon,
                    week_stats,
                }))
            } else {
                Err(e.into())
            }
        }
    }
}

/// This function is responsible for catching any panics that could possibly
/// occur.
fn get_server_status_catch_panic(
    address: *const c_char,
    protocol_type: ProtocolType,
    always_use_identicon: bool,
    app_group_container: *const c_char,
) -> Result<ServerStatus, anyhow::Error> {
    match panic::catch_unwind(|| {
        if address.is_null() {
            return Err(anyhow!("server address pointer was null"));
        }

        let address = unsafe { CStr::from_ptr(address) };
        let address = address
            .to_str()
            .with_context(|| "converting server address from cstr to rust str")?;

        if app_group_container.is_null() {
            return Err(anyhow!("app group container pointer was null"));
        }

        let app_group_container = unsafe { CStr::from_ptr(app_group_container) };
        let app_group_container = app_group_container
            .to_str()
            .with_context(|| "converting app group container from cstr to rust str")?;

        get_server_status_rust(
            address,
            protocol_type,
            always_use_identicon,
            app_group_container,
        )
    }) {
        Ok(result) => Ok(result?),
        Err(e) => Err(anyhow!("a panic occurred in rust code: {:?}", e)),
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
    protocol_type: ProtocolType,
    always_use_identicon: bool,
    app_group_container: *const c_char,
) -> ServerStatus {
    match get_server_status_catch_panic(
        address,
        protocol_type,
        always_use_identicon,
        app_group_container,
    ) {
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
        ServerStatus::Online(OnlineResponse { mcinfo, week_stats }) => {
            free_mcinfo(mcinfo);
            // `WeekStats` doesn't have any heap-allocated stuff, so we don't need
            // to free it
            drop(week_stats);
        }
        ServerStatus::Offline(OfflineResponse {
            favicon,
            week_stats,
        }) => {
            free_favicon(favicon);
            // `WeekStats` doesn't have any heap-allocated stuff, so we don't need
            // to free it
            drop(week_stats);
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

    free_favicon(mcinfo.favicon);

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

#[no_mangle]
pub extern "C" fn free_favicon(favicon: FaviconRaw) {
    match favicon {
        FaviconRaw::ServerProvided(p) | FaviconRaw::Generated(p) => {
            if !p.is_null() {
                let _ = unsafe { CString::from_raw(p) };
            }
        }
        FaviconRaw::NoFavicon => {}
    }
}
