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

private final class ShareSession {
	let callback: KapuschTikTokShareCallback
	let context: UnsafeMutableRawPointer
	private(set) var didFinish = false

	init(callback: @escaping KapuschTikTokShareCallback, context: UnsafeMutableRawPointer) {
		self.callback = callback
		self.context = context
	}

	func finish(status: ShareStatus, errorCode: String? = nil) {
		guard !didFinish else { return }
		didFinish = true
		invoke(callback, status: status, errorCode: errorCode, context: context)
	}
}

private final class ShareState {
	nonisolated(unsafe) static var request: TikTokShareRequest?
	nonisolated(unsafe) static var session: ShareSession?

	static func clear(_ session: ShareSession) {
		guard self.session === session else { return }
		request = nil
		self.session = nil
	}
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
	guard ShareState.session == nil else {
		invoke(callback, status: .failed, errorCode: "already_in_progress", context: context)
		return
	}

	let data = Data(String(cString: localIdentifiersJson).utf8)
	guard let localIdentifiers = try? JSONDecoder().decode([String].self, from: data),
		localIdentifiers.count >= 1,
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
	let session = ShareSession(callback: callback, context: context)
	ShareState.request = request
	ShareState.session = session
	let sent = request.send { response in
		defer { ShareState.clear(session) }
		guard let response = response as? TikTokShareResponse else {
			session.finish(status: .failed, errorCode: "invalid_share_response")
			return
		}
		switch response.shareState {
		case .success:
			session.finish(status: .success)
		case .saveAsDraft:
			session.finish(status: .draft)
		case .cancelled:
			session.finish(status: .cancelled)
		default:
			session.finish(
				status: .failed,
				errorCode: "tiktok_share_\(response.shareState.rawValue)_\(response.errorCode.rawValue)"
			)
		}
	}
	if !sent {
		session.finish(status: .failed, errorCode: "share_request_not_sent")
		ShareState.clear(session)
	}
}

@_cdecl("ktk_tiktok_abandon_pending_share")
public func ktk_tiktok_abandon_pending_share() -> Bool {
	guard let session = ShareState.session else { return false }
	session.finish(status: .cancelled, errorCode: "returned_without_callback")
	ShareState.clear(session)
	return true
}

@_cdecl("ktk_tiktok_handle_open_url")
public func ktk_tiktok_handle_open_url(_ urlPtr: UnsafeMutableRawPointer) -> Bool {
	let url = Unmanaged<NSURL>.fromOpaque(urlPtr).takeUnretainedValue() as URL
	let info = Bundle.main.infoDictionary ?? [:]
	let callbackScheme = info["TikTokURLScheme"] as? String
	let redirectURI = (info["TikTokRedirectURI"] as? String).flatMap(URL.init(string:))
	let isCustomSchemeCallback =
		url.scheme?.caseInsensitiveCompare(callbackScheme ?? "") == .orderedSame
	let isUniversalLinkCallback =
		url.scheme?.caseInsensitiveCompare(redirectURI?.scheme ?? "") == .orderedSame
		&& url.host?.caseInsensitiveCompare(redirectURI?.host ?? "") == .orderedSame
		&& url.path == redirectURI?.path
	guard isCustomSchemeCallback || isUniversalLinkCallback else {
		return false
	}
	return TikTokURLHandler.handleOpenURL(url)
}
