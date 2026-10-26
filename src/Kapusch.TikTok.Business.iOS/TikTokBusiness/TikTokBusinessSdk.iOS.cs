using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

namespace Kapusch.TikTok.Business.iOS;

/// <summary>
/// .NET facade over the TikTok Business SDK (App Events SDK) for iOS.
/// </summary>
/// <remarks>
/// Nothing is sent and no SDK state is created until <see cref="InitializeAsync"/> is called: every
/// other member returns <see langword="false"/> (or <see langword="null"/>) before a successful
/// initialization. Gate <see cref="InitializeAsync"/> on the user's consent.
/// </remarks>
public static unsafe partial class TikTokBusinessSdk
{
	/// <summary>
	/// Initializes the TikTok Business SDK on the main thread and completes with the SDK result.
	/// The SDK is a process-wide singleton: later calls return the current state without reconfiguring it.
	/// </summary>
	/// <exception cref="ArgumentException">A required value is missing or malformed.</exception>
	public static Task<TikTokBusinessInitResult> InitializeAsync(TikTokBusinessConfig config)
	{
		ArgumentNullException.ThrowIfNull(config);
		Validate(config);

		var completion = new TaskCompletionSource<TikTokBusinessInitResult>(
			TaskCreationOptions.RunContinuationsAsynchronously
		);
		var handle = GCHandle.Alloc(completion);
		try
		{
			InitializeNative(
				TikTokBusinessJson.WriteConfig(config),
				&InitializeCallback,
				GCHandle.ToIntPtr(handle)
			);
		}
		catch
		{
			handle.Free();
			throw;
		}
		return completion.Task;
	}

	/// <summary>
	/// Starts sending events after an initialization with <see cref="TikTokBusinessConfig.DisableAutoStart"/>
	/// (<c>setTrackingEnabled(true)</c> followed by a flush on iOS).
	/// </summary>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool StartTrack() => StartTrackNative() != 0;

	/// <summary>
	/// Enables or pauses sending. While disabled, the SDK keeps tracked events in its local store.
	/// </summary>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool SetTrackingEnabled(bool enabled) => SetTrackingEnabledNative(enabled ? (byte)1 : (byte)0) != 0;

	/// <summary>Tracks an event.</summary>
	/// <param name="eventName">A <see cref="TikTokBusinessEventNames"/> value or a custom name.</param>
	/// <param name="properties">
	/// Event properties, preferably <see cref="TikTokBusinessPropertyNames"/> keys. Values may be strings,
	/// booleans, numbers, nested dictionaries, lists or <see cref="TikTokBusinessContent"/>.
	/// </param>
	/// <param name="eventId">
	/// Optional deduplication identifier (for example a store transaction identifier). The SDK generates one when omitted.
	/// </param>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool TrackEvent(
		string eventName,
		IReadOnlyDictionary<string, object>? properties = null,
		string? eventId = null
	)
	{
		ArgumentException.ThrowIfNullOrWhiteSpace(eventName);
		return TrackEventNative(eventName, TikTokBusinessJson.WriteProperties(properties), NullIfEmpty(eventId)) != 0;
	}

	/// <summary>Tracks <see cref="TikTokBusinessEventNames.StartTrial"/>.</summary>
	public static bool TrackStartTrial(
		decimal? value = null,
		string? currency = null,
		string? eventId = null,
		string? contentId = null,
		string? contentType = null
	) => TrackEvent(TikTokBusinessEventNames.StartTrial, CommerceProperties(value, currency, contentId, contentType), eventId);

	/// <summary>Tracks <see cref="TikTokBusinessEventNames.Subscribe"/>.</summary>
	public static bool TrackSubscribe(
		decimal? value = null,
		string? currency = null,
		string? eventId = null,
		string? contentId = null,
		string? contentType = null
	) => TrackEvent(TikTokBusinessEventNames.Subscribe, CommerceProperties(value, currency, contentId, contentType), eventId);

	/// <summary>
	/// Tracks <see cref="TikTokBusinessEventNames.Purchase"/>, the App Events equivalent of a completed payment
	/// (the app SDK has no <c>CompletePayment</c> event).
	/// </summary>
	public static bool TrackPurchase(
		decimal? value = null,
		string? currency = null,
		string? eventId = null,
		string? contentId = null,
		string? contentType = null,
		IReadOnlyList<TikTokBusinessContent>? contents = null,
		string? description = null
	)
	{
		var properties = CommerceProperties(value, currency, contentId, contentType);
		if (contents is { Count: > 0 })
			properties[TikTokBusinessPropertyNames.Contents] = contents;
		if (!string.IsNullOrEmpty(description))
			properties[TikTokBusinessPropertyNames.Description] = description;
		return TrackEvent(TikTokBusinessEventNames.Purchase, properties, eventId);
	}

	/// <summary>Tracks <see cref="TikTokBusinessEventNames.Registration"/>.</summary>
	public static bool TrackRegistration(string? eventId = null) =>
		TrackEvent(TikTokBusinessEventNames.Registration, null, eventId);

	/// <summary>Tracks <see cref="TikTokBusinessEventNames.Login"/>.</summary>
	public static bool TrackLogin(string? eventId = null) =>
		TrackEvent(TikTokBusinessEventNames.Login, null, eventId);

	/// <summary>
	/// Advanced matching. The SDK hashes the values (SHA-256) on the device before sending them.
	/// The SDK keeps the first identity until <see cref="Logout"/> is called.
	/// </summary>
	/// <returns><see langword="false"/> when the SDK is not initialized or every value is empty.</returns>
	public static bool Identify(
		string? externalId,
		string? externalUserName = null,
		string? phoneNumber = null,
		string? email = null
	) =>
		IdentifyNative(
			NullIfEmpty(externalId),
			NullIfEmpty(externalUserName),
			NullIfEmpty(phoneNumber),
			NullIfEmpty(email)
		) != 0;

	/// <summary>Clears the identity set by <see cref="Identify"/> and rotates the anonymous identifier.</summary>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool Logout() => LogoutNative() != 0;

	/// <summary>Asks the SDK to send queued events now.</summary>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool Flush() => FlushNative() != 0;

	/// <summary>Replaces the App Secret used by the SDK (for example after a rotation in Events Manager).</summary>
	/// <returns><see langword="false"/> when the SDK is not initialized.</returns>
	public static bool UpdateAccessToken(string accessToken)
	{
		ArgumentException.ThrowIfNullOrWhiteSpace(accessToken);
		return UpdateAccessTokenNative(accessToken) != 0;
	}

	/// <summary>
	/// <see langword="true"/> once <see cref="InitializeAsync"/> configured the SDK in this process,
	/// including the deferred-start state.
	/// </summary>
	public static bool IsInitialized => IsInitializedNative() != 0;

	/// <summary><see langword="true"/> when the SDK is initialized and allowed to send events.</summary>
	public static bool IsTrackingEnabled => IsTrackingEnabledNative() != 0;

	/// <summary>Version of the bundled TikTok Business SDK, for example <c>1.7.2</c>.</summary>
	public static string SdkVersion => TakeString(SdkVersionNative()) ?? string.Empty;

	/// <summary>
	/// Test event code to enter in Events Manager, Test Events. Only available when the SDK runs with
	/// <see cref="TikTokBusinessConfig.DebugMode"/>; <see langword="null"/> otherwise.
	/// </summary>
	public static string? TestEventCode => TakeString(TestEventCodeNative());

	private static Dictionary<string, object> CommerceProperties(
		decimal? value,
		string? currency,
		string? contentId,
		string? contentType
	)
	{
		var properties = new Dictionary<string, object>(StringComparer.Ordinal);
		if (value is { } amount)
		{
			if (amount < 0)
				throw new ArgumentOutOfRangeException(nameof(value), "TikTok event values must not be negative.");
			if (string.IsNullOrEmpty(currency))
				throw new ArgumentException("A currency is required when a value is provided.", nameof(currency));
			// TikTokContentsEvent.setValue: takes a string on iOS; keep the same wire shape.
			properties[TikTokBusinessPropertyNames.Value] = TikTokBusinessJson.FormatDecimal(amount);
		}
		if (!string.IsNullOrEmpty(currency))
		{
			if (!CurrencyPattern().IsMatch(currency))
				throw new ArgumentException("Currency must be an ISO 4217 code such as USD or EUR.", nameof(currency));
			properties[TikTokBusinessPropertyNames.Currency] = currency;
		}
		if (!string.IsNullOrEmpty(contentId))
			properties[TikTokBusinessPropertyNames.ContentId] = contentId;
		if (!string.IsNullOrEmpty(contentType))
			properties[TikTokBusinessPropertyNames.ContentType] = contentType;
		return properties;
	}

	private static void Validate(TikTokBusinessConfig config)
	{
		ArgumentException.ThrowIfNullOrWhiteSpace(config.AppId, nameof(config.AppId));
		ArgumentException.ThrowIfNullOrWhiteSpace(config.AccessToken, nameof(config.AccessToken));
		if (!NumericPattern().IsMatch(config.AppId))
			throw new ArgumentException("AppId must be the numeric App Store ID.", nameof(config));
		if (config.TikTokAppIds is null || config.TikTokAppIds.Count == 0)
			throw new ArgumentException("At least one TikTok App ID is required.", nameof(config));
		foreach (var tiktokAppId in config.TikTokAppIds)
		{
			if (string.IsNullOrEmpty(tiktokAppId) || !NumericPattern().IsMatch(tiktokAppId))
				throw new ArgumentException("Each TikTok App ID must be numeric, without spaces or commas.", nameof(config));
		}
		if (config.AttAuthorizationDelay is { } delay && delay < TimeSpan.Zero)
			throw new ArgumentOutOfRangeException(nameof(config), "AttAuthorizationDelay must not be negative.");
	}

	private static string? NullIfEmpty(string? value) => string.IsNullOrEmpty(value) ? null : value;

	private static string? TakeString(IntPtr pointer)
	{
		if (pointer == IntPtr.Zero)
			return null;
		try
		{
			return Marshal.PtrToStringUTF8(pointer);
		}
		finally
		{
			StringFreeNative(pointer);
		}
	}

	[GeneratedRegex("^[0-9]+$", RegexOptions.CultureInvariant)]
	private static partial Regex NumericPattern();

	[GeneratedRegex("^[A-Z]{3}$", RegexOptions.CultureInvariant)]
	private static partial Regex CurrencyPattern();

	[UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
	private static void InitializeCallback(int status, int errorCode, IntPtr errorMessage, IntPtr context)
	{
		var handle = GCHandle.FromIntPtr(context);
		var completion = (TaskCompletionSource<TikTokBusinessInitResult>)handle.Target!;
		try
		{
			completion.TrySetResult(
				new TikTokBusinessInitResult(
					(TikTokBusinessInitStatus)status,
					errorCode,
					Marshal.PtrToStringUTF8(errorMessage)
				)
			);
		}
		finally
		{
			handle.Free();
		}
	}

	[LibraryImport("__Internal", EntryPoint = "ktkb_initialize", StringMarshalling = StringMarshalling.Utf8)]
	private static partial void InitializeNative(
		string configJson,
		delegate* unmanaged[Cdecl]<int, int, IntPtr, IntPtr, void> callback,
		IntPtr context
	);

	[LibraryImport("__Internal", EntryPoint = "ktkb_start_track")]
	private static partial byte StartTrackNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_set_tracking_enabled")]
	private static partial byte SetTrackingEnabledNative(byte enabled);

	[LibraryImport("__Internal", EntryPoint = "ktkb_track_event", StringMarshalling = StringMarshalling.Utf8)]
	private static partial byte TrackEventNative(string eventName, string? propertiesJson, string? eventId);

	[LibraryImport("__Internal", EntryPoint = "ktkb_identify", StringMarshalling = StringMarshalling.Utf8)]
	private static partial byte IdentifyNative(
		string? externalId,
		string? externalUserName,
		string? phoneNumber,
		string? email
	);

	[LibraryImport("__Internal", EntryPoint = "ktkb_logout")]
	private static partial byte LogoutNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_flush")]
	private static partial byte FlushNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_update_access_token", StringMarshalling = StringMarshalling.Utf8)]
	private static partial byte UpdateAccessTokenNative(string accessToken);

	[LibraryImport("__Internal", EntryPoint = "ktkb_is_initialized")]
	private static partial byte IsInitializedNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_is_tracking_enabled")]
	private static partial byte IsTrackingEnabledNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_sdk_version")]
	private static partial IntPtr SdkVersionNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_test_event_code")]
	private static partial IntPtr TestEventCodeNative();

	[LibraryImport("__Internal", EntryPoint = "ktkb_string_free")]
	private static partial void StringFreeNative(IntPtr pointer);
}
