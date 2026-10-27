namespace Kapusch.TikTok.Business.iOS;

/// <summary>
/// Standard TikTok App Events names, spelled exactly as TikTok Business iOS SDK 1.7.2 sends them
/// (<c>TikTokConstants.m</c> and <c>TikTokContentsEvent.m</c>). TikTok matches names case-sensitively.
/// </summary>
public static class TikTokBusinessEventNames
{
	/// <summary>Level achieved.</summary>
	public const string AchieveLevel = "AchieveLevel";

	/// <summary>Payment information added.</summary>
	public const string AddPaymentInfo = "AddPaymentInfo";

	/// <summary>Item added to cart (contents event).</summary>
	public const string AddToCart = "AddToCart";

	/// <summary>Item added to wishlist (contents event).</summary>
	public const string AddToWishlist = "AddToWishlist";

	/// <summary>Checkout started (contents event).</summary>
	public const string Checkout = "Checkout";

	/// <summary>Tutorial completed.</summary>
	public const string CompleteTutorial = "CompleteTutorial";

	/// <summary>Group created.</summary>
	public const string CreateGroup = "CreateGroup";

	/// <summary>Role created.</summary>
	public const string CreateRole = "CreateRole";

	/// <summary>Lead generated.</summary>
	public const string GenerateLead = "GenerateLead";

	/// <summary>Impression-level ad revenue.</summary>
	public const string ImpressionLevelAdRevenue = "ImpressionLevelAdRevenue";

	/// <summary>In-app ad clicked. The iOS SDK spells it <c>InAppADClick</c>.</summary>
	public const string InAppAdClick = "InAppADClick";

	/// <summary>In-app ad impression. The iOS SDK spells it <c>InAppADImpr</c>.</summary>
	public const string InAppAdImpression = "InAppADImpr";

	/// <summary>App installed. Sent automatically on the first initialization unless disabled.</summary>
	public const string InstallApp = "InstallApp";

	/// <summary>Group joined.</summary>
	public const string JoinGroup = "JoinGroup";

	/// <summary>App launched. Sent automatically on every initialization unless disabled. The SDK spells it <c>LaunchAPP</c>.</summary>
	public const string LaunchApp = "LaunchAPP";

	/// <summary>Loan application (deprecated upstream).</summary>
	[Obsolete("Deprecated by the TikTok Business SDK.")]
	public const string LoanApplication = "LoanApplication";

	/// <summary>Loan approval (deprecated upstream).</summary>
	[Obsolete("Deprecated by the TikTok Business SDK.")]
	public const string LoanApproval = "LoanApproval";

	/// <summary>Loan disbursal (deprecated upstream).</summary>
	[Obsolete("Deprecated by the TikTok Business SDK.")]
	public const string LoanDisbursal = "LoanDisbursal";

	/// <summary>User logged in.</summary>
	public const string Login = "Login";

	/// <summary>Purchase completed (contents event). Also sent automatically by the SDK purchase observer unless disabled.</summary>
	public const string Purchase = "Purchase";

	/// <summary>Rating submitted.</summary>
	public const string Rate = "Rate";

	/// <summary>User registered.</summary>
	public const string Registration = "Registration";

	/// <summary>Search performed.</summary>
	public const string Search = "Search";

	/// <summary>Credits spent.</summary>
	public const string SpendCredits = "SpendCredits";

	/// <summary>Free trial started.</summary>
	public const string StartTrial = "StartTrial";

	/// <summary>Paid subscription started.</summary>
	public const string Subscribe = "Subscribe";

	/// <summary>Achievement unlocked.</summary>
	public const string UnlockAchievement = "UnlockAchievement";

	/// <summary>Content viewed (contents event).</summary>
	public const string ViewContent = "ViewContent";

	/// <summary>
	/// Day-2 retention. Sent automatically by the SDK only; listed so hosts can recognise it.
	/// The iOS SDK spells it <c>2Dretention</c>.
	/// </summary>
	public const string SecondDayRetention = "2Dretention";

	/// <summary>Restored purchase. Sent automatically by the SDK purchase observer only.</summary>
	public const string PurchaseRestored = "PurchaseRestored";
}
