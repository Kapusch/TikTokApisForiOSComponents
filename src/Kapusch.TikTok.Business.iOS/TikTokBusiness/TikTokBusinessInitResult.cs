namespace Kapusch.TikTok.Business.iOS;

/// <summary>Outcome of <see cref="TikTokBusinessSdk.InitializeAsync"/>.</summary>
public enum TikTokBusinessInitStatus
{
	/// <summary>The SDK is initialized and sends events.</summary>
	Started = 0,

	/// <summary>
	/// The SDK is configured with <see cref="TikTokBusinessConfig.DisableAutoStart"/> and queues events
	/// until <see cref="TikTokBusinessSdk.StartTrack"/> is called.
	/// </summary>
	InitializedTrackingDisabled = 1,

	/// <summary>Initialization failed. See <see cref="TikTokBusinessInitResult.ErrorCode"/>.</summary>
	Failed = 2,
}

/// <summary>Result of <see cref="TikTokBusinessSdk.InitializeAsync"/>.</summary>
/// <param name="Status">Initialization outcome.</param>
/// <param name="ErrorCode">
/// The SDK error code (negative values, for example <c>-2</c> for an App ID / TikTok App ID mismatch)
/// or a wrapper code (<see cref="InvalidConfigurationErrorCode"/>, <see cref="ConfigurationRejectedErrorCode"/>).
/// <c>0</c> when there is no error.
/// </param>
/// <param name="ErrorMessage">SDK or wrapper diagnostic message.</param>
public sealed record TikTokBusinessInitResult(
	TikTokBusinessInitStatus Status,
	int ErrorCode = 0,
	string? ErrorMessage = null
)
{
	/// <summary>The native layer could not read the configuration.</summary>
	public const int InvalidConfigurationErrorCode = 1001;

	/// <summary>The SDK rejected the configuration values (for example a non-numeric App ID).</summary>
	public const int ConfigurationRejectedErrorCode = 1002;

	/// <summary><see langword="true"/> unless <see cref="Status"/> is <see cref="TikTokBusinessInitStatus.Failed"/>.</summary>
	public bool IsSuccess => Status != TikTokBusinessInitStatus.Failed;
}
