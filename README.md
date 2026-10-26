# TikTok APIs for iOS components

.NET iOS interop and deterministic native packaging for two TikTok SDKs. Each package
ships its native XCFramework and the official privacy manifests. Consumer builds never
invoke SwiftPM or download TikTok sources.

| Package | Upstream SDK | Purpose |
|---|---|---|
| `Kapusch.TikTok.iOS` | TikTok OpenSDK 2.5.0, Core and Share | Share images to TikTok. |
| `Kapusch.TikTok.Business.iOS` | TikTok Business SDK (App Events SDK) 1.7.2 | Install, launch and in-app event measurement for TikTok ads. |

The packages are independent: different upstream SDKs, credentials, privacy posture and
release tags. An app can reference either one or both.

## Kapusch.TikTok.iOS (Share)

```bash
bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj -c Release
```

The consuming app must configure `TikTokClientKey`, `TikTokRedirectURI`, `TikTokURLScheme`,
the registered URL scheme and the associated domain required by its approved TikTok
application. See [`Docs/Integration.md`](Docs/Integration.md) and
[`Docs/SourceMode.md`](Docs/SourceMode.md).

## Kapusch.TikTok.Business.iOS (App Events)

```bash
bash src/Kapusch.TikTok.Business.iOS/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTok.Business.iOS/Kapusch.TikTok.Business.iOS.csproj -c Release
```

```csharp
var result = await TikTokBusinessSdk.InitializeAsync(new TikTokBusinessConfig
{
	AppId = "<numeric App Store ID>",
	TikTokAppIds = ["<TikTok App ID>"],
	AccessToken = "<App Secret>",
	DisablePaymentTracking = true,
});
TikTokBusinessSdk.TrackSubscribe(9.99m, "EUR", eventId: "<store transaction id>");
```

Nothing starts before `InitializeAsync`: call it only after the user's consent. Read
[`Docs/Business/Integration.md`](Docs/Business/Integration.md) for the consent recipe,
automatic purchase double counting, App Tracking Transparency, SKAdNetwork and privacy
manifest guidance, and [`Docs/Business/SourceMode.md`](Docs/Business/SourceMode.md) for
source mode.

## Repository guides

- [`Docs/Release.md`](Docs/Release.md): tags and publishing for both packages.
- [`samples/`](samples/): secret-free integration samples.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): local validation and dependency-update rules.
- Third-party notices: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) (Share) and
  [`src/Kapusch.TikTok.Business.iOS/THIRD_PARTY_NOTICES.md`](src/Kapusch.TikTok.Business.iOS/THIRD_PARTY_NOTICES.md) (Business).

Tags reachable from `master` publish to NuGet.org: `vX.Y.Z` for the Share package and
`business-vX.Y.Z` for the Business package. Manual runs without a version publish a preview
package to GitHub Packages.
