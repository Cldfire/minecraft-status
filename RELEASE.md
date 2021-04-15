# Release

This file documents the release process for Minecraft Status.

## TestFlight

1. Bump build / version numbers for all targets
1. Update changelog
1. Do a `cargo clean`
1. Switch to the "Minecraft Status" scheme in XCode, building for "Any iOS Device"
1. Product > Archive from the menubar
1. Window > Organizer from the menubar
1. Select the new archive, click "Validate App" and run through that
1. Select the new archive, click "Distribute App" and upload the archive to the app store
  * Make sure to not include bitcode
1. Wait for the build to appear in App Store Connect
1. Wait for the build to be processed
1. Handle the "Manage Compliance" stuff
1. Add it to the TestFlight group so testers can install it
1. Commit and tag release (tag format: v0.0.1-3 where 3 is the build number)
