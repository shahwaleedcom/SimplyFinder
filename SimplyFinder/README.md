# SimplyFinder

SimplyFinder is a SwiftUI application that stores text, photos, and other files in folders using Core Data with CloudKit. The project is provided as an Xcode project.

## Requirements
- Xcode 14 or later

## Building
Open `SimplyFinder/SimplyFinder.xcodeproj` in Xcode and run the `SimplyFinder` scheme. There are no command‑line build steps or tests in this repository.

Document picking is only supported on iOS. On iPhone, imported documents now save both their name and data so you can view them later without reimporting.

## iPad Support
The interface adapts to iPad screens. When using the camera, the picker now presents in full‑screen mode on iPad to avoid the view being clipped.

## Troubleshooting
When running in a sandboxed environment you may see log output similar to:

```
NSBundle (null) initWithPath failed because the resolved path is empty or nil
networkd_settings_read_from_file Sandbox is preventing this process from reading networkd settings file at "/Library/Preferences/com.apple.networkd.plist"
ViewBridge to RemoteViewService Terminated: ... NSViewBridgeErrorCanceled
UINavigationBar has changed horizontal size class without updating search bar to new placement
Failed to create 0x88 image slot
unable to find unknown slice or a compatible one in binary archive
```

These messages come from system frameworks and usually do not indicate a problem with the app. They occur when the sandbox prevents access to system preferences, UIKit adjusts layout, or GPU services are unavailable. Unless the app crashes, they can be ignored. The first message about `NSBundle (null)` typically happens when a framework attempts to load a bundle using an empty path; SimplyFinder itself does not load bundles by path, so the log is harmless.

You may also see additional lines from frameworks such as Core Data or Siri, for example:

```
Core Data store loaded: <NSPersistentStoreDescription ...>
-[AFPreferences _languageCodeWithFallback:] No language code saved, but Assistant is enabled - returning: en-US
GenerativeModelsAvailability.Parameters: Initialized with invalid language code: en-US. Expected to receive two-letter ISO 639 code. e.g. 'zh' or 'en'. Falling back to: en
AFIsDeviceGreymatterEligible Missing entitlements for os_eligibility lookup
```

These are also benign and normally occur when running without Siri or generative model entitlements.

The SQLite store used by Core Data will be created under:
`~/Library/Containers/meez.SimplyFinder/Data/Library/Application Support/SimplyFinder/JarData.sqlite`

Make sure your iCloud entitlements are configured if you want to sync data via CloudKit.

## Support
For help and troubleshooting, see [docs/support.md](docs/support.md).

