using System.Buffers;
using System.Collections;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace Kapusch.TikTok.Business.iOS;

// Reflection-free JSON writer (trim and AOT safe) for the values crossing the native boundary.
internal static class TikTokBusinessJson
{
	public static string WriteConfig(TikTokBusinessConfig config)
	{
		var buffer = new ArrayBufferWriter<byte>();
		using (var writer = new Utf8JsonWriter(buffer))
		{
			writer.WriteStartObject();
			writer.WriteString("appId", config.AppId);
			writer.WriteString("tiktokAppId", string.Join(",", config.TikTokAppIds));
			writer.WriteString("accessToken", config.AccessToken);
			writer.WriteBoolean("debugMode", config.DebugMode);
			if (config.LogLevel is { } logLevel)
				writer.WriteNumber("logLevel", (int)logLevel);
			writer.WriteBoolean("disableAutoStart", config.DisableAutoStart);
			writer.WriteBoolean("disableAutomaticTracking", config.DisableAutomaticTracking);
			writer.WriteBoolean("disableInstallTracking", config.DisableInstallTracking);
			writer.WriteBoolean("disableLaunchTracking", config.DisableLaunchTracking);
			writer.WriteBoolean("disableRetentionTracking", config.DisableRetentionTracking);
			writer.WriteBoolean("disablePaymentTracking", config.DisablePaymentTracking);
			writer.WriteBoolean("disableSKAdNetworkSupport", config.DisableSKAdNetworkSupport);
			writer.WriteBoolean("disableEnhancedDataPostback", config.DisableEnhancedDataPostback);
			writer.WriteBoolean("limitedDataUse", config.LimitedDataUse);
			if (config.AttAuthorizationDelay is { } delay)
				writer.WriteNumber("attDelaySeconds", (long)Math.Ceiling(delay.TotalSeconds));
			if (!string.IsNullOrEmpty(config.CustomUserAgent))
				writer.WriteString("customUserAgent", config.CustomUserAgent);
			writer.WriteBoolean("lowPerformanceDevice", config.LowPerformanceDevice);
			writer.WriteEndObject();
		}
		return Encoding.UTF8.GetString(buffer.WrittenSpan);
	}

	public static string? WriteProperties(IReadOnlyDictionary<string, object>? properties)
	{
		if (properties is null || properties.Count == 0)
			return null;
		var buffer = new ArrayBufferWriter<byte>();
		using (var writer = new Utf8JsonWriter(buffer))
		{
			WriteObject(writer, properties.Select(static pair => new KeyValuePair<string, object?>(pair.Key, pair.Value)), depth: 0);
		}
		return Encoding.UTF8.GetString(buffer.WrittenSpan);
	}

	private const int MaxDepth = 8;

	private static void WriteObject(
		Utf8JsonWriter writer,
		IEnumerable<KeyValuePair<string, object?>> properties,
		int depth
	)
	{
		writer.WriteStartObject();
		foreach (var (key, value) in properties)
		{
			ArgumentException.ThrowIfNullOrEmpty(key, nameof(properties));
			writer.WritePropertyName(key);
			WriteValue(writer, value, depth + 1);
		}
		writer.WriteEndObject();
	}

	private static void WriteValue(Utf8JsonWriter writer, object? value, int depth)
	{
		if (depth > MaxDepth)
			throw new ArgumentException("TikTok event properties are nested too deeply.");

		switch (value)
		{
			case null:
				writer.WriteNullValue();
				break;
			case string text:
				writer.WriteStringValue(text);
				break;
			case bool flag:
				writer.WriteBooleanValue(flag);
				break;
			case decimal number:
				writer.WriteNumberValue(number);
				break;
			case double number when double.IsFinite(number):
				writer.WriteNumberValue(number);
				break;
			case float number when float.IsFinite(number):
				writer.WriteNumberValue(number);
				break;
			case int or long or short or byte or sbyte or ushort or uint:
				writer.WriteNumberValue(Convert.ToInt64(value, CultureInfo.InvariantCulture));
				break;
			case ulong number:
				writer.WriteNumberValue(number);
				break;
			case DateTimeOffset timestamp:
				writer.WriteStringValue(timestamp.ToString("O", CultureInfo.InvariantCulture));
				break;
			case DateTime timestamp:
				writer.WriteStringValue(timestamp.ToString("O", CultureInfo.InvariantCulture));
				break;
			case TikTokBusinessContent content:
				WriteContent(writer, content);
				break;
			case IEnumerable<KeyValuePair<string, object?>> nested:
				WriteObject(writer, nested, depth);
				break;
			case IDictionary dictionary:
				writer.WriteStartObject();
				foreach (DictionaryEntry entry in dictionary)
				{
					var key = Convert.ToString(entry.Key, CultureInfo.InvariantCulture);
					if (string.IsNullOrEmpty(key))
						throw new ArgumentException("TikTok event property keys must be non-empty strings.");
					writer.WritePropertyName(key);
					WriteValue(writer, entry.Value, depth + 1);
				}
				writer.WriteEndObject();
				break;
			case IEnumerable items:
				writer.WriteStartArray();
				foreach (var item in items)
					WriteValue(writer, item, depth + 1);
				writer.WriteEndArray();
				break;
			default:
				throw new ArgumentException(
					$"Unsupported TikTok event property value type '{value.GetType().FullName}'. "
						+ "Use strings, booleans, numbers, dictionaries, lists or TikTokBusinessContent."
				);
		}
	}

	private static void WriteContent(Utf8JsonWriter writer, TikTokBusinessContent content)
	{
		// Mirrors TikTokContentParams.dictionaryValue: price is a string, quantity a number.
		writer.WriteStartObject();
		writer.WriteString(
			TikTokBusinessPropertyNames.Price,
			FormatDecimal(content.Price ?? 0m)
		);
		writer.WriteNumber(TikTokBusinessPropertyNames.Quantity, content.Quantity);
		if (!string.IsNullOrEmpty(content.ContentId))
			writer.WriteString(TikTokBusinessPropertyNames.ContentId, content.ContentId);
		if (!string.IsNullOrEmpty(content.ContentCategory))
			writer.WriteString(TikTokBusinessPropertyNames.ContentCategory, content.ContentCategory);
		if (!string.IsNullOrEmpty(content.ContentName))
			writer.WriteString(TikTokBusinessPropertyNames.ContentName, content.ContentName);
		if (!string.IsNullOrEmpty(content.Brand))
			writer.WriteString(TikTokBusinessPropertyNames.Brand, content.Brand);
		writer.WriteEndObject();
	}

	public static string FormatDecimal(decimal value) =>
		value.ToString("0.############################", CultureInfo.InvariantCulture);
}
