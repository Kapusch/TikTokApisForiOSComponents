using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Kapusch.TikTok.iOS;

public static unsafe class NativeTikTokShare
{
	public static Task<NativeTikTokShareResult> ShareImagesAsync(
		IReadOnlyList<string> localIdentifiers,
		CancellationToken cancellationToken = default
	)
	{
		ArgumentNullException.ThrowIfNull(localIdentifiers);
		if (localIdentifiers.Count is < 2 or > 12)
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
			ResolveShareImages()(jsonPointer, &ShareCallback, GCHandle.ToIntPtr(handle));
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
		return ResolveHandleOpenUrl()(nsUrlHandle) != 0;
	}

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

	private static IntPtr Resolve(string symbol) =>
		NativeLibrary.GetExport(NativeLibrary.GetMainProgramHandle(), symbol);

	private static delegate* unmanaged[Cdecl]<
		IntPtr,
		delegate* unmanaged[Cdecl]<int, IntPtr, IntPtr, void>,
		IntPtr,
		void> ResolveShareImages() =>
		(delegate* unmanaged[Cdecl]<
			IntPtr,
			delegate* unmanaged[Cdecl]<int, IntPtr, IntPtr, void>,
			IntPtr,
			void>)Resolve("ktk_tiktok_share_images");

	private static delegate* unmanaged[Cdecl]<IntPtr, byte> ResolveHandleOpenUrl() =>
		(delegate* unmanaged[Cdecl]<IntPtr, byte>)Resolve("ktk_tiktok_handle_open_url");
}
