# minecraft-status changelog

Notable `minecraft-status` changes, tracked in the [keep a changelog](https://keepachangelog.com/en/1.0.0/) format with the addition of the `Internal` change type.

## [Unreleased]

### Added

* Server favicons are now cached
  * Offline servers are now neatly displayed as being offline in the widget (as long as the server was successfully pinged before)

### Changed

* Latency is no longer considered when choosing a color for the status circle
  * It's now either green when the server is online or gray when it's offline
  * I personally found using latency as a data point to be more annoying than helpful

### Internal

* Set up CI
* Added build setup guide
* Reorganized the repo

## [0.1.0-3] - 2021-01-28

Initial release.

[Unreleased]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-3...HEAD
[0.1.0-3]: https://github.com/Cldfire/minecraft-status/releases/tag/v0.0.1-3
