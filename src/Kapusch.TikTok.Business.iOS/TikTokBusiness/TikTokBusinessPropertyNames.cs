namespace Kapusch.TikTok.Business.iOS;

/// <summary>
/// Standard TikTok App Events property names. TikTok documents that custom property keys are not
/// supported and are discarded, so stick to these keys.
/// </summary>
public static class TikTokBusinessPropertyNames
{
	/// <summary>Monetary value of the event (sent as a decimal string by the SDK contents events).</summary>
	public const string Value = "value";

	/// <summary>ISO 4217 currency code, for example <c>USD</c> or <c>EUR</c>.</summary>
	public const string Currency = "currency";

	/// <summary>Identifier of the content (for example a product or plan identifier).</summary>
	public const string ContentId = "content_id";

	/// <summary>Type of the content, for example <c>product</c> or <c>product_group</c>.</summary>
	public const string ContentType = "content_type";

	/// <summary>Free-form description.</summary>
	public const string Description = "description";

	/// <summary>Array of content items. Use <see cref="TikTokBusinessContent"/> with the typed helpers.</summary>
	public const string Contents = "contents";

	/// <summary>Content item price (inside <see cref="Contents"/>).</summary>
	public const string Price = "price";

	/// <summary>Content item quantity (inside <see cref="Contents"/>).</summary>
	public const string Quantity = "quantity";

	/// <summary>Content item category (inside <see cref="Contents"/>).</summary>
	public const string ContentCategory = "content_category";

	/// <summary>Content item name (inside <see cref="Contents"/>).</summary>
	public const string ContentName = "content_name";

	/// <summary>Content item brand (inside <see cref="Contents"/>).</summary>
	public const string Brand = "brand";

	/// <summary>Ad revenue payload of <see cref="TikTokBusinessEventNames.ImpressionLevelAdRevenue"/>.</summary>
	public const string AdRevenue = "ad_revenue";
}

/// <summary>One entry of the <c>contents</c> array, matching <c>TikTokContentParams</c>.</summary>
/// <param name="ContentId">Content identifier.</param>
/// <param name="Price">Unit price. <see langword="null"/> sends the SDK default (<c>0</c>).</param>
/// <param name="Quantity">Quantity.</param>
/// <param name="ContentCategory">Optional category.</param>
/// <param name="ContentName">Optional name.</param>
/// <param name="Brand">Optional brand.</param>
public sealed record TikTokBusinessContent(
	string? ContentId = null,
	decimal? Price = null,
	int Quantity = 1,
	string? ContentCategory = null,
	string? ContentName = null,
	string? Brand = null
);
