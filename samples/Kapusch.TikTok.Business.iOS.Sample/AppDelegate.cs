using AppTrackingTransparency;
using Foundation;
using Kapusch.TikTok.Business.iOS;
using UIKit;

namespace Kapusch.TikTok.Business.iOS.Sample;

[Register("AppDelegate")]
public sealed class AppDelegate : UIApplicationDelegate
{
	private UILabel? _status;

	public override UIWindow? Window { get; set; }

	public override bool FinishedLaunching(UIApplication application, NSDictionary? launchOptions)
	{
		// Before consent nothing reaches the SDK: calls are rejected and return false.
		Console.WriteLine(
			$"[tiktok-business-sample] sdk={TikTokBusinessSdk.SdkVersion} initialized={TikTokBusinessSdk.IsInitialized} "
				+ $"trackBeforeInit={TikTokBusinessSdk.TrackLogin()} flushBeforeInit={TikTokBusinessSdk.Flush()}"
		);

		_status = new UILabel
		{
			Lines = 0,
			TextAlignment = UITextAlignment.Center,
			Text = $"TikTok Business SDK {TikTokBusinessSdk.SdkVersion}\nNot initialized.",
		};
		var start = UIButton.FromType(UIButtonType.System);
		start.SetTitle("I consent: start TikTok App Events", UIControlState.Normal);
		start.TouchUpInside += async (_, _) => await StartAfterConsentAsync();

		var stack = new UIStackView([_status, start])
		{
			Axis = UILayoutConstraintAxis.Vertical,
			Spacing = 24,
			TranslatesAutoresizingMaskIntoConstraints = false,
		};
		var controller = new UIViewController();
		controller.View!.BackgroundColor = UIColor.SystemBackground;
		controller.View.AddSubview(stack);
		NSLayoutConstraint.ActivateConstraints(
			[
				stack.CenterYAnchor.ConstraintEqualTo(controller.View.CenterYAnchor),
				stack.LeadingAnchor.ConstraintEqualTo(controller.View.LeadingAnchor, 24),
				stack.TrailingAnchor.ConstraintEqualTo(controller.View.TrailingAnchor, -24),
			]
		);

		Window = new UIWindow(UIScreen.MainScreen.Bounds) { RootViewController = controller };
		Window.MakeKeyAndVisible();
		return true;
	}

	// Consent first, then App Tracking Transparency, then the SDK. Nothing TikTok-related runs before this.
	private async Task StartAfterConsentAsync()
	{
		var config = ReadLocalConfig();
		if (config is null)
		{
			SetStatus("Fill the Sample* keys in the untracked Info.plist (see README).");
			return;
		}

		var attStatus = await ATTrackingManager.RequestTrackingAuthorizationAsync();
		var result = await TikTokBusinessSdk.InitializeAsync(config);
		if (!result.IsSuccess)
		{
			SetStatus($"Initialization failed: {result.ErrorCode} {result.ErrorMessage}");
			return;
		}

		TikTokBusinessSdk.TrackEvent(
			TikTokBusinessEventNames.ViewContent,
			new Dictionary<string, object>
			{
				[TikTokBusinessPropertyNames.ContentId] = "sample-screen",
				[TikTokBusinessPropertyNames.ContentType] = "product",
			}
		);
		TikTokBusinessSdk.TrackStartTrial(0m, "USD", eventId: $"sample-trial-{Guid.NewGuid():N}", contentId: "sample-plan");
		TikTokBusinessSdk.Flush();

		SetStatus(
			$"Status: {result.Status}\nATT: {attStatus}\nTracking: {TikTokBusinessSdk.IsTrackingEnabled}\n"
				+ $"Test event code: {TikTokBusinessSdk.TestEventCode ?? "(debug mode off)"}"
		);
	}

	private static TikTokBusinessConfig? ReadLocalConfig()
	{
		var info = NSBundle.MainBundle.InfoDictionary;
		string Read(string key) => info.ObjectForKey(new NSString(key))?.ToString()?.Trim() ?? string.Empty;

		var appId = Read("SampleTikTokBusinessAppId");
		var tiktokAppId = Read("SampleTikTokBusinessTikTokAppId");
		var accessToken = Read("SampleTikTokBusinessAccessToken");
		if (appId.Length == 0 || tiktokAppId.Length == 0 || accessToken.Length == 0)
			return null;

		return new TikTokBusinessConfig
		{
			AppId = appId,
			TikTokAppIds = tiktokAppId.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
			AccessToken = accessToken,
			DebugMode = true,
			LogLevel = TikTokBusinessLogLevel.Debug,
			// Manual subscription events are the source of truth: avoid automatic Purchase double counting.
			DisablePaymentTracking = true,
			DisableEnhancedDataPostback = true,
		};
	}

	private void SetStatus(string text)
	{
		if (_status is not null)
			_status.Text = text;
	}
}
