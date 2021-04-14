//! Provides a common Rust abstraction over both the Java and Bedrock ping protocols.
//!
//! This abstraction provides the ability to both ping an address with a given
//! protocol and ping an address with both protocols, returning in all cases a
//! unified response type that communicates which protocol was successful.

use std::{io, sync::mpsc, thread, time::Duration};

/// The various protocol types that can be used for a ping.
#[repr(C)]
#[derive(Debug, Clone, Copy, Eq, PartialEq, Hash)]
pub enum ProtocolType {
    /// Ping using the Java protocol only.
    Java,
    /// Ping using the Bedrock protocol only.
    Bedrock,
    /// Ping using all protocols, returning the first successful ping result.
    Auto,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash)]
pub struct Response {
    pub protocol_type: ProtocolType,
    pub latency: u64,
    pub version: Version,
    pub players: Players,
    // TODO: turn this into a rich text type
    pub motd: String,
    /// The server icon (a Base64-encoded PNG image).
    pub favicon: Option<String>,
}

impl Response {
    fn from_java(latency: u64, v: mcping::JavaResponse) -> Self {
        Self {
            protocol_type: ProtocolType::Java,
            latency,
            version: Version {
                name: v.version.name,
                protocol: Some(v.version.protocol),
            },
            players: Players {
                online: v.players.online,
                max: v.players.max,
                sample: v
                    .players
                    .sample
                    .into_iter()
                    .flatten()
                    .map(|p| Player {
                        name: p.name,
                        id: p.id,
                    })
                    .collect(),
            },
            motd: v.description.text().to_string(),
            favicon: v.favicon,
        }
    }

    fn from_bedrock(latency: u64, v: mcping::BedrockResponse) -> Self {
        Self {
            protocol_type: ProtocolType::Bedrock,
            latency,
            version: Version {
                name: v.version_name,
                protocol: v.protocol_version,
            },
            players: Players {
                online: v.players_online.unwrap_or(0),
                max: v.players_max.unwrap_or(0),
                sample: vec![],
            },
            motd: format!(
                "motd1: {} motd2: {}",
                v.motd_1,
                v.motd_2.unwrap_or_default()
            ),
            favicon: None,
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq, Hash)]
pub struct Version {
    pub name: String,
    pub protocol: Option<i64>,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash)]
pub struct Players {
    pub online: i64,
    pub max: i64,
    pub sample: Vec<Player>,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash)]
pub struct Player {
    pub name: String,
    pub id: String,
}

/// A common `get_status` function that can ping Java or Bedrock (or intelligently
/// try both).
pub fn get_status(
    server_address: String,
    timeout: Option<Duration>,
    protocol_type: ProtocolType,
) -> Result<Response, mcping::Error> {
    match protocol_type {
        ProtocolType::Java => mcping::get_status(mcping::Java {
            server_address,
            timeout,
        })
        .map(|(latency, response)| Response::from_java(latency, response)),
        ProtocolType::Bedrock => mcping::get_status(mcping::Bedrock {
            server_address,
            timeout,
            ..Default::default()
        })
        .map(|(latency, response)| Response::from_bedrock(latency, response)),
        ProtocolType::Auto => get_status_auto(server_address, timeout),
    }
}

/// Implements trying both protocol pings and returning the first successful result.
fn get_status_auto(
    server_address: String,
    timeout: Option<Duration>,
) -> Result<Response, mcping::Error> {
    enum ResponseType {
        Java((u64, mcping::JavaResponse)),
        Bedrock((u64, mcping::BedrockResponse)),
    }

    let (tx, rx) = mpsc::channel::<Result<ResponseType, mcping::Error>>();

    let tx2 = tx.clone();
    let server_address2 = server_address.clone();

    thread::spawn(move || {
        let _ = tx.send(
            mcping::get_status(mcping::Java {
                server_address,
                timeout,
            })
            .map(|(latency, response)| ResponseType::Java((latency, response))),
        );
    });

    thread::spawn(move || {
        let _ = tx2.send(
            mcping::get_status(mcping::Bedrock {
                server_address: server_address2,
                timeout,
                ..Default::default()
            })
            .map(|(latency, response)| ResponseType::Bedrock((latency, response))),
        );
    });

    for _ in 0..2 {
        // Return the first successful response, if any
        if let Ok(Ok(response_type)) = rx.recv() {
            return Ok(match response_type {
                ResponseType::Java((latency, response)) => Response::from_java(latency, response),
                ResponseType::Bedrock((latency, response)) => {
                    Response::from_bedrock(latency, response)
                }
            });
        }
    }

    Err(mcping::Error::IoError(io::Error::new(
        io::ErrorKind::TimedOut,
        "neither thread returned a valid response",
    )))
}
