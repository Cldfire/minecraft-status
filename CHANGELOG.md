# minecraft-status changelog

Notable `minecraft-status` changes, tracked in the [keep a changelog](https://keepachangelog.com/en/1.0.0/) format with the addition of the `Internal` change type.

## [Unreleased]

### Added

* Added support for pinging Bedrock servers
* Added an auto-detect mode that will successfully ping both Bedrock and Java servers
* Added identicon generation to provide an icon for servers that don't set one
  * Bedrock servers can't set icons at all, so this is especially important there
* Added a toggle to choose between displaying the server's favicon or a generated identicon
* Added a link to my Twitter so you can follow me ;)

### Internal

* Moved all of the business logic entirely into Rust
* Created a basic test suite to ensure the core logic doesn't break

## [v0.1.0-4] - 2021-02-28

A small iteration on the first beta release with some quality of life improvements.

### Added

* Server favicons are now cached
  * Offline servers are now neatly displayed as being offline in the widget (as long as the server was successfully pinged before)

### Changed

* Latency is no longer considered when choosing a color for the status circle
  * It's now either green when the server is online or gray when it's offline
  * I personally found using latency as a data point to be more annoying than helpful
* TCP connections are now performed with a five-second timeout
  * A widget trying to ping "google.com" will now timeout and display an error message instead of remaining in the redacted view forever

### Fixed

* The app no longer crashes when tapping "Share" on an iPad

### Internal

* Set up CI
* Added build setup guide
* Reorganized the repo

## [v0.1.0-3] - 2021-01-28

Initial release.

[Unreleased]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-4...HEAD
[v0.1.0-4]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-3...v0.0.1-4
[v0.1.0-3]: https://github.com/Cldfire/minecraft-status/releases/tag/v0.0.1-3
