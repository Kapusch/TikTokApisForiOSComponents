# Kapusch.TikTok.Business.iOS

Pinned TikTok Business SDK (App Events SDK) 1.7.2 for .NET iOS. The package contains a
single static XCFramework (thin `ktkb_*` facade plus the SDK compiled from its
checksum-locked source) and the official privacy manifest. Consumer builds do not
download Swift packages or TikTok sources.

```csharp
var result = await TikTokBusinessSdk.InitializeAsync(new TikTokBusinessConfig
{
	AppId = "<App Store ID>",
	TikTokAppIds = ["<TikTok App ID>"],
	AccessToken = "<App Secret>",
	DisablePaymentTracking = true,
});
TikTokBusinessSdk.TrackStartTrial(0m, "USD", eventId: "<transaction id>");
```

Nothing starts before `InitializeAsync`: gate it on consent. See the repository
`Docs/Business/Integration.md` for consent, App Tracking Transparency, SKAdNetwork and
in-app purchase double-counting guidance.
