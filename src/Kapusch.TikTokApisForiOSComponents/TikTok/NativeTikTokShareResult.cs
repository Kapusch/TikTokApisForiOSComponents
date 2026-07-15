namespace Kapusch.TikTok.iOS;

public enum NativeTikTokShareStatus
{
	Success,
	Draft,
	Cancelled,
	Failed,
}

public sealed record NativeTikTokShareResult(
	NativeTikTokShareStatus Status,
	string? ErrorCode = null
);
