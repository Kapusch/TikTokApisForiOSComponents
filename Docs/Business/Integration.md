# Kapusch.TikTok.Business.iOS integration

`Kapusch.TikTok.Business.iOS` wraps the TikTok Business SDK (also called the TikTok App
Events SDK) 1.7.2 for .NET iOS. It measures app installs, launches and in-app events
for TikTok ads attribution and optimization. It is a separate package from
`Kapusch.TikTok.iOS` (OpenSDK Share). Both packages can be referenced by the same app:
CI checks that their static archives define no common strong symbol.

## 1. Values from Events Manager

In TikTok Ads Manager, open Tools, Events Manager, connect an App data source and choose
the SDK integration. Then collect three values:

| `TikTokBusinessConfig` | Events Manager | Notes |
|---|---|---|
| `AppId` | App ID | The numeric App Store ID on iOS. |
| `TikTokAppIds` | TikTok App ID | One per ad account. Several IDs are allowed. |
| `AccessToken` | App Secret (Settings tab) | The SDK calls it `accessToken`. |

The SDK refuses to initialize when the TikTok App IDs do not belong to the App ID
(error code `-2`). The App Secret is embedded in the shipped app by design of the SDK.
Keep it out of source control anyway, for example in build-time configuration.

## 2. What happens before `InitializeAsync`

- **Nothing is sent, and no SDK object is created.** Every `TikTokBusinessSdk` member
  other than `InitializeAsync` and `SdkVersion` returns `false` (or `null`) until a
  successful initialization. In particular, `Identify` does not persist identity data
  early.
- **Linking the SDK still runs a few upstream load-time hooks** (Objective-C `+load` and
  C constructors). They make no network request, but they keep local state:
  - The crash component (`TTSDKCrash`) starts an app-state tracker and registers its
    monitors. The crash handler itself is installed only after initialization, and only
    when TikTok's remote configuration enables it (`crash_monitor_enable`).
  - `NSObject+TikTokAdditions` observes `UIApplicationDidFinishLaunchingNotification`.
    It writes the launch URL and a launch "referrer" to `NSUserDefaults` (keys
    `source_url` and `refer`). For a launch from a remote notification, the referrer is
    the notification payload as JSON. The SDK reads these values later to report launch
    sources.
  - The same category swizzles `application:openURL:options:` on a class named
    `<CFBundleDisplayName>.AppDelegate`, if such a class exists. A .NET app delegate
    registered with `[Register("AppDelegate")]` does not match, so nothing is swizzled
    by default.

Mention the launch-referrer storage in your privacy review if launches from
notifications carry personal data.

## 3. Consent recipe

TikTok's compliance guidance says not to initialize the SDK before the user is allowed
to be tracked (for example after consent or an age gate). The wrapper follows that model:

1. Show your consent UI first. Do not call `InitializeAsync` before a "yes".
2. After a "yes", optionally ask for App Tracking Transparency
   (`ATTrackingManager.RequestTrackingAuthorizationAsync()`). The SDK never shows the ATT
   prompt itself in 1.7.x, so `DisableAppTrackingDialog` has no effect. Without ATT the
   SDK sends no IDFA, only the vendor identifier.
3. Call `InitializeAsync` once per process, on any thread. The wrapper runs the SDK
   initialization on the main thread and completes with `Started`.
4. Track events. On later launches, call `InitializeAsync` again early, for example in
   `FinishedLaunching`, as long as the stored consent is still "yes".

```csharp
if (consentStore.TikTokAllowed)
{
	await ATTrackingManager.RequestTrackingAuthorizationAsync();
	var result = await TikTokBusinessSdk.InitializeAsync(new TikTokBusinessConfig
	{
		AppId = appConfig.AppStoreId,
		TikTokAppIds = appConfig.TikTokAppIds,
		AccessToken = appConfig.TikTokAppSecret,
		DisablePaymentTracking = true,      // see section 4
		DisableEnhancedDataPostback = true, // no automatic UI capture
	});
	if (!result.IsSuccess)
		logger.Warn($"TikTok init failed: {result.ErrorCode} {result.ErrorMessage}");
}
```

Important behaviour:

- **The install is still counted** when initialization happens later than the first
  launch: the SDK reports `InstallApp` at its first successful initialization. TikTok
  also warns that existing users count as installs the first time they open a version
  that contains the SDK, so wait a few days before you judge campaigns.
- **`DisableAutoStart` is not a consent gate.** With it, `InitializeAsync` completes with
  `InitializedTrackingDisabled` and the SDK queues events until `StartTrack()`. However,
  the SDK still downloads its remote configuration from TikTok during initialization,
  with app and device information. Also, in 1.7.2, events read by a flush while sending
  is disabled may only leave the device on the next launch. Use it only to configure
  early and start in the same session after a decision you already hold.
- **Revocation.** The SDK cannot be shut down inside a running process. On revocation,
  call `SetTrackingEnabled(false)` to stop sending (events stay queued locally) and
  `Logout()` to clear any identity. Then do not call `InitializeAsync` on later launches.
- `AttAuthorizationDelay` delays the first flush (`setDelayForATTUserAuthorizationInSeconds`),
  for an app that initializes before its ATT prompt.

## 4. Automatic in-app purchase tracking and double counting

By default the SDK observes StoreKit. On iOS 15 and later it polls `Transaction.all`
about every 600 seconds; TikTok's server can change this interval. It reports:

- **every** successful transaction as `Purchase`, including free-trial starts and
  renewals, valued at `quantity x Product.price`. That is the catalog price, not the
  amount actually paid, so a free trial can show up as a full-price purchase;
- the current entitlements found at start as `PurchaseRestored`.

It never emits `StartTrial` or `Subscribe`. If you also send those events yourself, or
read purchases from a subscription backend, conversions are counted twice and revenue
is inflated.

**Recommendation:** set `DisablePaymentTracking = true` and send the events yourself
from your purchase flow, with the store transaction identifier as `eventId`:

```csharp
TikTokBusinessSdk.TrackStartTrial(0m, "EUR", eventId: transaction.Id, contentId: productId);
TikTokBusinessSdk.TrackSubscribe(9.99m, "EUR", eventId: transaction.Id, contentId: productId);
```

Caveat: `DisablePaymentTracking` only sends a preference (`auto_iap_track_config=2`) to
TikTok. The SDK then follows the server value `auto_track_Payment_enable`, which defaults
to "on". Check in Events Manager, Test Events, that no automatic `Purchase` arrives. If
one does, the only local hard switch is `DisableAutomaticTracking = true`. It also stops
the automatic `InstallApp`, `LaunchAPP` and `2Dretention` events, so you would then send
`InstallApp` once and `LaunchAPP` at each launch yourself with `TrackEvent`.

## 5. Events and properties

- `TikTokBusinessEventNames` lists every standard name of SDK 1.7.2, spelled as the SDK
  sends it (for example `LaunchAPP`, `InAppADClick`, `2Dretention`). The app SDK has no
  `CompletePayment` event: use `Purchase`.
- `TikTokBusinessPropertyNames` lists the standard keys (`value`, `currency`,
  `content_id`, `content_type`, `description`, `contents` and the content item keys).
  TikTok documents that custom property keys are discarded.
- The typed helpers send `value` as a decimal string, like the SDK's own
  `TikTokContentsEvent.setValue:`. A currency (ISO 4217, for example `EUR`) is required
  with a value.
- Pass `eventId` (for example the store transaction identifier) so TikTok can
  deduplicate the event. The SDK generates one when you omit it.
- `Identify` sends advanced-matching data. The SDK hashes it (SHA-256) on the device.
  The first identity is kept until `Logout()`.
- In debug mode, `TikTokBusinessSdk.TestEventCode` returns the code to enter in Events
  Manager, Test Events. Never ship `DebugMode = true`.

## 6. SKAdNetwork

- By default the SDK registers the app for ad network attribution at its first
  initialization. It then updates SKAdNetwork conversion values according to the SKAN
  schema configured in Events Manager (SKAN 3, and SKAN 4 on iOS 16.1 and later). SDK
  1.7.2 has no AdAttributionKit support.
- **Only one SDK in the app should update conversion values.** If another SDK or a
  mobile measurement partner owns them, set `DisableSKAdNetworkSupport = true`.
- When TikTok, or another non-MMP SDK, owns the conversion values, upload a matching
  schema in Events Manager (Tracking Settings, Configure SKAN). When an MMP owns them,
  TikTok imports the MMP schema.
- An advertised app needs no `SKAdNetworkItems` entries for install validation. Those
  entries matter only to apps that display ads.

## 7. Privacy manifest and App Store declarations

- The package bundles the official SDK manifest as
  `TikTokBusinessSDK_Privacy.bundle/PrivacyInfo.xcprivacy`, unchanged. It declares only
  `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`). It has an empty placeholder
  collected-data entry, and no `NSPrivacyTracking` or `NSPrivacyTrackingDomains`.
- The SDK binary also calls `sysctl` for `kern.boottime` (system boot time),
  `NSFileSystemSize` (disk space) and `stat`. These are required-reason APIs that its
  manifest does not declare. Review them and declare suitable reasons in the app's own
  privacy manifest to avoid App Store Connect warnings.
- Your App Store privacy answers, and your own manifest, must describe what the app
  collects through the SDK (device identifiers, usage data, purchases) and whether it is
  used for tracking.
- All SDK traffic goes to `analytics.us.tiktok.com` by default; the server can change
  the domain. If you list that domain in `NSPrivacyTrackingDomains`, iOS blocks every
  request to it while ATT is not authorized. That would also block measurement for users
  who declined ATT.

## 8. Linking

The NuGet injects one static `ktkbusiness.xcframework`. It is force-loaded, which covers
the SDK's `-ObjC` requirement. It also adds `-lc++`, `-lsqlite3`, `-lz`, the SDK system
frameworks and a weak `AppTrackingTransparency`. The .NET iOS SDK links the Swift
runtime. Nothing is downloaded at consumer build time. Set
`DisableKapuschTikTokBusinessIosNativeAssets=true` to skip the native injection, for
example in a unit-test project.

The SDK installs its own crash monitor when TikTok's remote configuration enables it.
Qualify crash reporting when the app also uses another crash reporter.

Because the archive is force-loaded, every global it defines is linked into the app. Two
upstream globals have generic, unprefixed names:

| Symbol | Upstream definition |
|---|---|
| `_handleConfiguration` | function in `TTSDKCrash/TTSDKCrashRecording/TTSDKCrashC.c` (KSCrash-derived) |
| `_defaultPattern` | `NSString * const` in `Core/TikTokViewUtility.m` |

Another static library in the app that defines a strong global with the same name makes
the link fail with a duplicate-symbol error. Other KSCrash-derived crash reporters and
other Objective-C SDKs are the likely sources. The wrapper does not rename upstream
symbols, because it never patches upstream sources. To check your own static SDKs, build
this package and run:

```sh
scripts/check-native-symbol-collisions.sh --with path/to/Other.xcframework --with path/to/libOther.a
```
