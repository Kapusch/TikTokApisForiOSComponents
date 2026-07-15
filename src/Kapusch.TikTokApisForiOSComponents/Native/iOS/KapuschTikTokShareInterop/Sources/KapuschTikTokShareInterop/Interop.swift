import Foundation

import TikTokOpenSDKCore
import TikTokOpenShareSDK

public typealias KapuschTikTokShareCallback = @convention(c) (
	Int32,
	UnsafePointer<CChar>?,
	UnsafeMutableRawPointer
) -> Void

private enum ShareStatus: Int32 {
	case success = 0
	case draft = 1
	case cancelled = 2
	case failed = 3
}

private final class ShareState {
	nonisolated(unsafe) static var request: TikTokShareRequest?
}

private func invoke(
	_ callback: KapuschTikTokShareCallback,
	status: ShareStatus,
	errorCode: String? = nil,
	context: UnsafeMutableRawPointer
) {
	guard let errorCode else {
		callback(status.rawValue, nil, context)
		return
	}
	errorCode.withCString { callback(status.rawValue, $0, context) }
}

@_cdecl("ktk_tiktok_share_images")
public func ktk_tiktok_share_images(
	_ localIdentifiersJson: UnsafePointer<CChar>,
	_ callback: @escaping KapuschTikTokShareCallback,
	_ context: UnsafeMutableRawPointer
) {
	guard ShareState.request == nil else {
		invoke(callback, status: .failed, errorCode: "already_in_progress", context: context)
		return
	}

	let data = Data(String(cString: localIdentifiersJson).utf8)
	guard let localIdentifiers = try? JSONDecoder().decode([String].self, from: data),
		localIdentifiers.count >= 2,
		localIdentifiers.count <= 12
	else {
		invoke(callback, status: .failed, errorCode: "invalid_image_identifiers", context: context)
		return
	}

	let info = Bundle.main.infoDictionary ?? [:]
	guard let redirectURI = info["TikTokRedirectURI"] as? String,
		!redirectURI.isEmpty,
		let clientKey = info["TikTokClientKey"] as? String,
		!clientKey.isEmpty,
		let urlScheme = info["TikTokURLScheme"] as? String,
		!urlScheme.isEmpty
	else {
		invoke(callback, status: .failed, errorCode: "tiktok_configuration_missing", context: context)
		return
	}

	let request = TikTokShareRequest(
		localIdentifiers: localIdentifiers,
		mediaType: .image,
		redirectURI: redirectURI
	)
	request.customConfig = .init(clientKey: clientKey, callerUrlScheme: urlScheme)
	ShareState.request = request
	let sent = request.send { response in
		defer { ShareState.request = nil }
		guard let response = response as? TikTokShareResponse else {
			invoke(callback, status: .failed, errorCode: "invalid_share_response", context: context)
			return
		}
		switch response.shareState {
		case .success:
			invoke(callback, status: .success, context: context)
		case .saveAsDraft:
			invoke(callback, status: .draft, context: context)
		case .cancelled:
			invoke(callback, status: .cancelled, context: context)
		default:
			invoke(
				callback,
				status: .failed,
				errorCode: "tiktok_share_\(response.shareState.rawValue)_\(response.errorCode.rawValue)",
				context: context
			)
		}
	}
	if !sent {
		ShareState.request = nil
		invoke(callback, status: .failed, errorCode: "share_request_not_sent", context: context)
	}
}

@_cdecl("ktk_tiktok_handle_open_url")
public func ktk_tiktok_handle_open_url(_ urlPtr: UnsafeMutableRawPointer) -> Bool {
	let url = Unmanaged<NSURL>.fromOpaque(urlPtr).takeUnretainedValue() as URL
	return TikTokURLHandler.handleOpenURL(url)
}
