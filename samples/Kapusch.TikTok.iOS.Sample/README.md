# Minimal integration sample

Configure a real TikTok client key, HTTPS redirect URI, matching associated domain and callback URL scheme locally. Do not commit those values.

Forward both callback forms from the application delegate:

```csharp
public override bool OpenUrl(UIApplication app, NSUrl url, NSDictionary options) =>
	NativeTikTokShare.HandleOpenUrl(url.Handle);

public override bool ContinueUserActivity(
	UIApplication application,
	NSUserActivity userActivity,
	UIApplicationRestorationHandler completionHandler
) =>
	userActivity.WebPageUrl is { } url
	&& NativeTikTokShare.HandleOpenUrl(url.Handle);
```

After obtaining add-only Photos permission and creating two assets, pass their local identifiers in display order:

```csharp
var result = await NativeTikTokShare.ShareImagesAsync(
	[firstImageAsset.LocalIdentifier, secondImageAsset.LocalIdentifier],
	CancellationToken.None
);

Console.WriteLine($"TikTok share: {result.Status} {result.ErrorCode}");
```

The SDK handoff and callback require an approved TikTok application and a physical device with TikTok installed.
