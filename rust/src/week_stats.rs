//! Implements the week stats backend.
//!
//! Collects, stores, and hands out ping stats about a Minecraft server over the
//! last week or so.

use std::{collections::BTreeMap, fs, ops::RangeBounds, path::Path};

use anyhow::Context;
use chrono::{DateTime, Duration, Local, Timelike, Utc};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Default)]
struct PingStatsOnDisk {
    /// History entries keyed by unix timestamp.
    ping_history: BTreeMap<i64, HistoryEntry>,
}

impl PingStatsOnDisk {
    /// Trim outdated entries from the beginning of the stored ping history.
    ///
    /// An entry older than 10 days ago is considered to be outdated.
    pub fn trim_outdated(&mut self, now: DateTime<Utc>) {
        let cutoff = now - Duration::days(10);
        let cutoff_timestamp = cutoff.timestamp();

        // TODO: use BTreeMap::retain when it's stable
        let remaining = self.ping_history.split_off(&cutoff_timestamp);
        self.ping_history = remaining;
    }

    /// Incorporate the given ping data appropriately into the stored entries.
    pub fn add_data(&mut self, now: DateTime<Utc>, current_online: i64, current_max: i64) {
        self.ping_history
            .entry(now.timestamp())
            .or_default()
            .update(current_online, current_max);
    }

    /// Return `RangeStats` built from data within the given timestamp range.
    pub fn range_stats(&self, timestamp_range: impl RangeBounds<i64>) -> RangeStats {
        let mut num_entries = 0;
        let mut total_online = 0;
        let mut peak_online = 0;
        let mut peak_max = 0;

        for (_, v) in self.ping_history.range(timestamp_range) {
            num_entries += 1;
            total_online += v.online;

            peak_online = peak_online.max(v.online);
            peak_max = peak_max.max(v.max);
        }

        RangeStats {
            average_online: if num_entries == 0 {
                0
            } else {
                total_online / num_entries
            },
            peak_online,
            peak_max,
        }
    }

    /// Build `WeekStats` from the current state of the data.
    pub fn week_stats(&self, now_timestamp: i64, seconds_from_midnight: i64) -> WeekStats {
        let today_midnight = now_timestamp - seconds_from_midnight;

        /// Returns the number of seconds in `n` days.
        fn days(n: i64) -> i64 {
            60 * 60 * 24 * n
        }

        let daily_stats = [
            self.range_stats((today_midnight - days(7))..(today_midnight - days(6))),
            self.range_stats((today_midnight - days(6))..(today_midnight - days(5))),
            self.range_stats((today_midnight - days(5))..(today_midnight - days(4))),
            self.range_stats((today_midnight - days(4))..(today_midnight - days(3))),
            self.range_stats((today_midnight - days(3))..(today_midnight - days(2))),
            self.range_stats((today_midnight - days(2))..(today_midnight - days(1))),
            self.range_stats((today_midnight - days(1))..today_midnight),
            self.range_stats(today_midnight..=now_timestamp),
        ];

        let peak_online = daily_stats
            .iter()
            .map(|s| s.peak_online)
            .max()
            .unwrap_or_default();

        let peak_max = daily_stats
            .iter()
            .map(|s| s.peak_max)
            .max()
            .unwrap_or_default();

        WeekStats {
            daily_stats,
            peak_online,
            peak_max,
        }
    }
}

/// A ping history entry.
#[derive(Serialize, Deserialize, Default, Clone)]
struct HistoryEntry {
    /// The number of players online at this time.
    pub online: i64,
    /// The max number of players allowed online at this time.
    pub max: i64,
}

impl HistoryEntry {
    /// Update this history entry with new data.
    fn update(&mut self, current_online: i64, current_max: i64) {
        self.online = current_online;
        self.max = current_max;
    }
}

/// Stats representing some range of time.
#[repr(C)]
#[derive(Default, Debug, Eq, PartialEq)]
pub struct RangeStats {
    /// The average number of players online during this period.
    pub average_online: i64,
    /// The peak number of online players during this period.
    pub peak_online: i64,
    /// The peak max allowed online players during this period.
    pub peak_max: i64,
}

#[repr(C)]
#[derive(Debug, Default)]
pub struct WeekStats {
    /// Stats for the last eight days.
    pub daily_stats: [RangeStats; 8],
    /// The peak number of online players during this period.
    pub peak_online: i64,
    /// The peak max allowed online players during this period.
    pub peak_max: i64,
}

pub fn determine_week_stats(
    path: impl AsRef<Path>,
    current_online: i64,
    current_max: i64,
) -> Result<WeekStats, anyhow::Error> {
    let path = path.as_ref();

    let now_local = Local::now();
    let now_utc = Utc::now();

    let mut data = if path.exists() {
        let data = fs::read(path)
            .with_context(|| format!("failed to read week stats file from {}", path.display()))?;
        // If parsing fails, we start fresh
        serde_json::from_slice(&data).unwrap_or_default()
    } else {
        PingStatsOnDisk::default()
    };

    data.trim_outdated(now_utc);
    data.add_data(now_utc, current_online, current_max);

    let week_stats = data.week_stats(
        now_local.timestamp(),
        now_local.num_seconds_from_midnight() as i64,
    );

    let updated_data =
        serde_json::to_string(&data).with_context(|| "failed to serialize week stats")?;
    fs::write(&path, &updated_data)
        .with_context(|| format!("failed to write week stats file to {}", path.display()))?;

    Ok(week_stats)
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;
    use tempfile::TempDir;

    use super::*;

    fn moment_utc() -> DateTime<Utc> {
        Utc.ymd(2021, 2, 14).and_hms(8, 12, 43)
    }

    fn test_data() -> PingStatsOnDisk {
        let mut data = PingStatsOnDisk::default();
        let moment = moment_utc();

        data.add_data(moment - Duration::days(12) - Duration::hours(3), 20, 70);
        data.add_data(moment - Duration::days(10) - Duration::hours(3), 20, 70);
        data.add_data(moment - Duration::days(10) + Duration::hours(4), 20, 40);
        data.add_data(moment - Duration::days(9), 20, 40);

        data.add_data(moment - Duration::days(6) - Duration::minutes(12), 13, 40);
        data.add_data(moment - Duration::days(6) + Duration::hours(5), 40, 40);

        data.add_data(moment - Duration::days(1) - Duration::hours(1), 4, 30);
        data.add_data(moment - Duration::days(1) - Duration::minutes(30), 3, 50);
        data.add_data(moment - Duration::days(1), 20, 30);

        data.add_data(moment - Duration::hours(2), 15, 30);
        data.add_data(moment - Duration::minutes(15), 5, 30);
        data.add_data(moment, 10, 30);

        data
    }

    #[test]
    fn trim_outdated() {
        let mut data = test_data();
        let original_length = data.ping_history.len();
        let moment = moment_utc();

        data.trim_outdated(moment);

        assert!(data.ping_history.len() < original_length);

        // These entries were outdated and should have been trimmed
        assert_eq!(
            data.ping_history
                .contains_key(&(moment - Duration::days(12) - Duration::hours(3)).timestamp()),
            false
        );
        assert_eq!(
            data.ping_history
                .contains_key(&(moment - Duration::days(10) - Duration::hours(3)).timestamp()),
            false
        );

        // These entries should have been kept
        assert_eq!(
            data.ping_history
                .contains_key(&(moment - Duration::days(10) + Duration::hours(4)).timestamp()),
            true
        );
        assert_eq!(
            data.ping_history
                .contains_key(&(moment - Duration::days(1)).timestamp()),
            true
        );
        assert_eq!(data.ping_history.contains_key(&moment.timestamp()), true);
    }

    #[test]
    fn week_stats() {
        let data = test_data();
        let moment = moment_utc();

        let week_stats = data.week_stats(
            moment.timestamp(),
            moment.num_seconds_from_midnight() as i64,
        );

        assert_eq!(week_stats.peak_online, 40);
        assert_eq!(week_stats.peak_max, 50);

        assert_eq!(
            week_stats.daily_stats,
            [
                RangeStats::default(),
                RangeStats {
                    average_online: 26,
                    peak_online: 40,
                    peak_max: 40,
                },
                RangeStats::default(),
                RangeStats::default(),
                RangeStats::default(),
                RangeStats::default(),
                RangeStats {
                    average_online: 9,
                    peak_online: 20,
                    peak_max: 50,
                },
                RangeStats {
                    average_online: 10,
                    peak_online: 15,
                    peak_max: 30,
                },
            ]
        );

        let week_stats = data.week_stats(moment.timestamp(), 300);

        assert_eq!(week_stats.peak_online, 40);
        assert_eq!(week_stats.peak_max, 50);

        assert_eq!(
            week_stats.daily_stats,
            [
                RangeStats {
                    average_online: 13,
                    peak_online: 13,
                    peak_max: 40
                },
                RangeStats {
                    average_online: 40,
                    peak_online: 40,
                    peak_max: 40
                },
                RangeStats::default(),
                RangeStats::default(),
                RangeStats::default(),
                RangeStats {
                    average_online: 3,
                    peak_online: 4,
                    peak_max: 50
                },
                RangeStats {
                    average_online: 13,
                    peak_online: 20,
                    peak_max: 30
                },
                RangeStats {
                    average_online: 10,
                    peak_online: 10,
                    peak_max: 30
                }
            ]
        );
    }

    // Test some aspects of interaction with the storage file
    #[test]
    fn file_handling() -> Result<(), anyhow::Error> {
        let tmp_dir = TempDir::new()?;
        let filepath = tmp_dir.path().join("week_stats");

        // File doesn't exist
        assert!(!filepath.exists());

        let _ = determine_week_stats(&filepath, 10, 40)?;

        // File exists now
        assert!(filepath.exists());

        let stats = determine_week_stats(&filepath, 20, 50)?;
        assert_eq!(stats.peak_online, 20);

        // Corrupt the file
        fs::write(&filepath, "getrekt")?;

        // Make sure we recover and start the file over
        let stats = determine_week_stats(&filepath, 10, 40)?;
        assert_eq!(stats.peak_online, 10);

        Ok(())
    }
}
