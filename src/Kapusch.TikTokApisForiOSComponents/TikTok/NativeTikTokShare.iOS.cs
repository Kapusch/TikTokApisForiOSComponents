using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Kapusch.TikTok.iOS;

public static unsafe partial class NativeTikTokShare
{
	public static Task<NativeTikTokShareResult> ShareImagesAsync(
		IReadOnlyList<string> localIdentifiers,
		CancellationToken cancellationToken = default
	)
	{
		ArgumentNullException.ThrowIfNull(localIdentifiers);
		if (localIdentifiers.Count is < 1 or > 12)
			throw new ArgumentOutOfRangeException(nameof(localIdentifiers));
		cancellationToken.ThrowIfCancellationRequested();

		var completion = new TaskCompletionSource<NativeTikTokShareResult>(
			TaskCreationOptions.RunContinuationsAsynchronously
		);
		var handle = GCHandle.Alloc(completion);
		var json = string.Concat(
			"[",
			string.Join(
				",",
				localIdentifiers.Select(identifier =>
					string.Concat("\"", JsonEncodedText.Encode(identifier), "\"")
				)
			),
			"]"
		);
		var jsonPointer = Marshal.StringToCoTaskMemUTF8(json);
		try
		{
			ShareImagesNative(jsonPointer, &ShareCallback, GCHandle.ToIntPtr(handle));
		}
		catch
		{
			handle.Free();
			throw;
		}
		finally
		{
			Marshal.FreeCoTaskMem(jsonPointer);
		}
		return completion.Task;
	}

	public static bool HandleOpenUrl(IntPtr nsUrlHandle)
	{
		if (nsUrlHandle == IntPtr.Zero)
			return false;
		return HandleOpenUrlNative(nsUrlHandle) != 0;
	}

	public static bool AbandonPendingShare() => AbandonPendingShareNative() != 0;

	[UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
	private static void ShareCallback(int status, IntPtr errorCode, IntPtr context)
	{
		var handle = GCHandle.FromIntPtr(context);
		var completion = (TaskCompletionSource<NativeTikTokShareResult>)handle.Target!;
		try
		{
			completion.TrySetResult(
				new NativeTikTokShareResult(
					(NativeTikTokShareStatus)status,
					Marshal.PtrToStringUTF8(errorCode)
				)
			);
		}
		finally
		{
			handle.Free();
		}
	}

	[LibraryImport("__Internal", EntryPoint = "ktk_tiktok_share_images")]
	private static partial void ShareImagesNative(
		IntPtr localIdentifiersJson,
		delegate* unmanaged[Cdecl]<int, IntPtr, IntPtr, void> callback,
		IntPtr context
	);

	[LibraryImport("__Internal", EntryPoint = "ktk_tiktok_handle_open_url")]
	private static partial byte HandleOpenUrlNative(IntPtr nsUrlHandle);

	[LibraryImport("__Internal", EntryPoint = "ktk_tiktok_abandon_pending_share")]
	private static partial byte AbandonPendingShareNative();
}
