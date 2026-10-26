namespace Kapusch.TikTok.Business.iOS;

/// <summary>
/// Configuration passed to <see cref="TikTokBusinessSdk.InitializeAsync"/>.
/// Values come from TikTok Events Manager (Ads Manager, Tools, Events Manager, your app, Settings).
/// </summary>
public sealed record TikTokBusinessConfig
{
	/// <summary>
	/// The store identifier of the app. On iOS this is the numeric App Store ID (for example <c>123456789</c>).
	/// </summary>
	public required string AppId { get; init; }

	/// <summary>
	/// One or several TikTok App IDs (one per ad account). Each ID is numeric. The SDK refuses to
	/// initialize when an ID does not belong to <see cref="AppId"/>.
	/// </summary>
	public required IReadOnlyList<string> TikTokAppIds { get; init; }

	/// <summary>
	/// The App Secret shown in Events Manager. The TikTok SDK names this value <c>accessToken</c>.
	/// Do not commit it to source control.
	/// </summary>
	public required string AccessToken { get; init; }

	/// <summary>Enables the SDK debug mode (test event code, verbose diagnostics). Never enable it in production.</summary>
	public bool DebugMode { get; init; }

	/// <summary>SDK log level. <see langword="null"/> keeps the SDK default.</summary>
	public TikTokBusinessLogLevel? LogLevel { get; init; }

	/// <summary>
	/// Configures the SDK without sending events. Events are queued until <see cref="TikTokBusinessSdk.StartTrack"/>.
	/// The SDK still downloads its remote configuration during initialization, so this is not a consent gate:
	/// call <see cref="TikTokBusinessSdk.InitializeAsync"/> only after consent instead.
	/// Maps to <c>TikTokConfig.disableTracking()</c> on iOS.
	/// </summary>
	public bool DisableAutoStart { get; init; }

	/// <summary>Disables every automatic event (install, launch, retention and the StoreKit purchase observer).</summary>
	public bool DisableAutomaticTracking { get; init; }

	/// <summary>Disables the automatic <c>InstallApp</c> event.</summary>
	public bool DisableInstallTracking { get; init; }

	/// <summary>Disables the automatic <c>LaunchAPP</c> event.</summary>
	public bool DisableLaunchTracking { get; init; }

	/// <summary>Disables the automatic <c>2Dretention</c> event.</summary>
	public bool DisableRetentionTracking { get; init; }

	/// <summary>
	/// Asks TikTok to disable automatic in-app purchase tracking. The SDK forwards this preference to its
	/// remote configuration, which makes the final decision. See Docs/Business/Integration.md.
	/// </summary>
	public bool DisablePaymentTracking { get; init; }

	/// <summary>
	/// Accepted for API symmetry. TikTok Business SDK 1.7.x never presents the App Tracking Transparency
	/// prompt itself (the upstream switch is deprecated and unused), so this has no effect on iOS.
	/// </summary>
	public bool DisableAppTrackingDialog { get; init; }

	/// <summary>Stops the SDK from registering for and updating SKAdNetwork conversion values.</summary>
	public bool DisableSKAdNetworkSupport { get; init; }

	/// <summary>
	/// Accepted for API symmetry with Android. iOS has no such switch: the SDK reads the IDFA only when
	/// App Tracking Transparency is authorized, and receives zeros otherwise.
	/// </summary>
	public bool DisableAdvertiserIdCollection { get; init; }

	/// <summary>Disables Enhanced Data Postback automatic UI event capture.</summary>
	public bool DisableEnhancedDataPostback { get; init; }

	/// <summary>Enables Limited Data Use mode.</summary>
	public bool LimitedDataUse { get; init; }

	/// <summary>
	/// Delays the first flush to leave time for an App Tracking Transparency decision
	/// (<c>setDelayForATTUserAuthorizationInSeconds</c>). <see langword="null"/> keeps the SDK default.
	/// </summary>
	public TimeSpan? AttAuthorizationDelay { get; init; }

	/// <summary>Custom user agent. <see langword="null"/> lets the SDK collect it.</summary>
	public string? CustomUserAgent { get; init; }

	/// <summary>Marks the device as low-performance so the SDK reduces optional work.</summary>
	public bool LowPerformanceDevice { get; init; }
}

/// <summary>TikTok SDK log level.</summary>
public enum TikTokBusinessLogLevel
{
	/// <summary>No SDK logs.</summary>
	None = 0,
	/// <summary>Errors only.</summary>
	Error = 1,
	/// <summary>Warnings and errors.</summary>
	Warn = 2,
	/// <summary>Informational messages.</summary>
	Info = 3,
	/// <summary>Debug messages.</summary>
	Debug = 4,
	/// <summary>Everything.</summary>
	Verbose = 5,
}
