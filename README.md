# SimplyFinder

SimplyFinder is a SwiftUI application that stores text, photos, and other files in folders using Core Data with CloudKit. The project is provided as an Xcode project.

## Requirements
- macOS 12 or later
- Xcode 14 or later

## Building
Open `SimplyFinder/SimplyFinder.xcodeproj` in Xcode and run the `SimplyFinder` scheme. There are no command‑line build steps or tests in this repository.

## Troubleshooting
When running in a sandboxed environment you may see log output similar to:

```
NSBundle (null) initWithPath failed because the resolved path is empty or nil
networkd_settings_read_from_file Sandbox is preventing this process from reading networkd settings file at "/Library/Preferences/com.apple.networkd.plist"
ViewBridge to RemoteViewService Terminated: ... NSViewBridgeErrorCanceled
```

These messages come from system frameworks and usually do not indicate a problem with the app. They occur when the sandbox prevents access to system preferences or when a remote view controller closes. Unless the app crashes, these logs can generally be ignored.

The SQLite store used by Core Data will be created under:
`~/Library/Containers/meez.SimplyFinder/Data/Library/Application Support/SimplyFinder/JarData.sqlite`

Make sure your iCloud entitlements are configured if you want to sync data via CloudKit.

