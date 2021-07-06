# minecraft-status changelog

Notable `minecraft-status` changes, tracked in the [keep a changelog](https://keepachangelog.com/en/1.0.0/) format with the addition of the `Internal` change type.

## [Unreleased]

## [v1.0.0-1] - 2021-07-05

The 1.0 release that will be going live on the App Store soon! While I was initially planning to add more widget types to the app prior to launching on the App Store, real-life time constraints put an end to those ideas, so I've cleaned up the wonderful existing functionality in the "Minecraft Server Icon" widget and gotten the necessary bits together to release Minecraft Status to the world.

### Changed

* The "Minecraft Server Icon" widget now has an improved appearance in the large size
* The app icon has been updated to be more release-worthy

### Fixed

* "Widget Setup" now links to the iPad widget help article on iPads

### Internal

* Set up a Swift CI test job
* Renamed a bunch of stuff for more consistent naming
* Fixed multiple build issues
* Disabled bitcode in the xcode project settings

## [v0.1.0-5] - 2021-04-14

This release adds support for pinging Bedrock Minecraft servers! The widgets default to an "Auto" mode that can ping any Minecraft server type successfully, and you can choose a specific type in the widget's settings as well if necessary.

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

[Unreleased]: https://github.com/Cldfire/minecraft-status/compare/v1.0.0-1...HEAD
[v1.0.0-1]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-5...v1.0.0-1
[v0.1.0-5]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-4...v0.0.1-5
[v0.1.0-4]: https://github.com/Cldfire/minecraft-status/compare/v0.0.1-3...v0.0.1-4
[v0.1.0-3]: https://github.com/Cldfire/minecraft-status/releases/tag/v0.0.1-3
