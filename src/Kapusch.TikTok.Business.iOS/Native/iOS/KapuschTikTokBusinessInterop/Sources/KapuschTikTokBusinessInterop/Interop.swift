import Foundation

import TikTokBusinessSDKCore

// Thin C facade over the TikTok Business SDK (App Events SDK).
// Every export is prefixed with `ktkb_` so it cannot collide with the Share package (`ktk_`).
// Strings and dictionaries cross the boundary as UTF-8 C strings / UTF-8 JSON.

public typealias KapuschTikTokBusinessInitCallback = @convention(c) (
	Int32,
	Int32,
	UnsafePointer<CChar>?,
	UnsafeMutableRawPointer
) -> Void

private enum InitStatus: Int32 {
	case started = 0
	case initializedTrackingDisabled = 1
	case failed = 2
}

// Wrapper-owned error codes. Native SDK codes (-1, -2, -3, ...) are forwarded unchanged.
private enum WrapperErrorCode: Int32 {
	case invalidConfiguration = 1001
	case configurationRejected = 1002
}

private struct BusinessConfig: Decodable, Sendable {
	let appId: String
	let tiktokAppId: String
	let accessToken: String
	let debugMode: Bool?
	let logLevel: Int?
	let disableAutoStart: Bool?
	let disableAutomaticTracking: Bool?
	let disableInstallTracking: Bool?
	let disableLaunchTracking: Bool?
	let disableRetentionTracking: Bool?
	let disablePaymentTracking: Bool?
	let disableSKAdNetworkSupport: Bool?
	let disableEnhancedDataPostback: Bool?
	let limitedDataUse: Bool?
	let attDelaySeconds: Int?
	let customUserAgent: String?
	let lowPerformanceDevice: Bool?
}

// Serialises completion for one initialize request; the SDK may call its completion synchronously.
private final class InitSession: @unchecked Sendable {
	private let callback: KapuschTikTokBusinessInitCallback
	private let context: UnsafeMutableRawPointer
	private var didFinish = false

	init(callback: @escaping KapuschTikTokBusinessInitCallback, context: UnsafeMutableRawPointer) {
		self.callback = callback
		self.context = context
	}

	func finish(_ status: InitStatus, code: Int32 = 0, message: String? = nil) {
		guard !didFinish else { return }
		didFinish = true
		guard let message else {
			callback(status.rawValue, code, nil, context)
			return
		}
		message.withCString { callback(status.rawValue, code, $0, context) }
	}
}

// Whether InitializeAsync configured the SDK in this process. Every other export is a no-op that
// returns false until then, so nothing touches the SDK (or persists identity data) before the host
// explicitly initializes it.
private enum SdkState {
	private static let lock = NSLock()
	nonisolated(unsafe) private static var _configured = false

	static var configured: Bool {
		get { lock.withLock { _configured } }
		set { lock.withLock { _configured = newValue } }
	}
}

private func string(_ pointer: UnsafePointer<CChar>?) -> String? {
	guard let pointer else { return nil }
	let value = String(cString: pointer)
	return value.isEmpty ? nil : value
}

private func duplicate(_ value: String?) -> UnsafeMutablePointer<CChar>? {
	guard let value else { return nil }
	return strdup(value)
}

private func logLevel(_ value: Int) -> TikTokLogLevel? {
	switch value {
	case 0: return TikTokLogLevelSuppress
	case 1: return TikTokLogLevelError
	case 2: return TikTokLogLevelWarn
	case 3: return TikTokLogLevelInfo
	case 4: return TikTokLogLevelDebug
	case 5: return TikTokLogLevelVerbose
	default: return nil
	}
}

private func makeConfig(_ settings: BusinessConfig) -> TikTokConfig? {
	guard let config = TikTokConfig(
		accessToken: settings.accessToken,
		appId: settings.appId,
		tiktokAppId: settings.tiktokAppId
	) else {
		return nil
	}
	if settings.disableAutoStart == true { config.disableTracking() }
	if settings.disableAutomaticTracking == true { config.disableAutomaticTracking() }
	if settings.disableInstallTracking == true { config.disableInstallTracking() }
	if settings.disableLaunchTracking == true { config.disableLaunchTracking() }
	if settings.disableRetentionTracking == true { config.disableRetentionTracking() }
	if settings.disablePaymentTracking == true { config.disablePaymentTracking() }
	// disableAppTrackingDialog is deprecated upstream and has no effect in 1.7.x: the SDK never
	// presents the ATT prompt itself. The flag is accepted for API symmetry and intentionally ignored.
	if settings.disableSKAdNetworkSupport == true { config.disableSKAdNetworkSupport() }
	if settings.disableEnhancedDataPostback == true { config.disableAutoEnhancedDataPostbackEvent() }
	if settings.limitedDataUse == true { config.enableLDUMode() }
	if settings.lowPerformanceDevice == true { config.setIsLowPerformanceDevice(true) }
	if let seconds = settings.attDelaySeconds, seconds > 0 {
		config.setDelayForATTUserAuthorizationInSeconds(seconds)
	}
	if let userAgent = settings.customUserAgent, !userAgent.isEmpty {
		config.setCustomUserAgent(userAgent)
	}
	if settings.debugMode == true { config.enableDebugMode() }
	if let value = settings.logLevel, let level = logLevel(value) {
		config.setLogLevel(level)
	}
	return config
}

private func runOnMain(_ body: @escaping @Sendable () -> Void) {
	if Thread.isMainThread {
		body()
	} else {
		DispatchQueue.main.async(execute: body)
	}
}

private func currentStartedStatus() -> InitStatus {
	TikTokBusiness.isTrackingEnabled() ? .started : .initializedTrackingDisabled
}

@_cdecl("ktkb_initialize")
public func ktkb_initialize(
	_ configJson: UnsafePointer<CChar>,
	_ callback: @escaping KapuschTikTokBusinessInitCallback,
	_ context: UnsafeMutableRawPointer
) {
	let session = InitSession(callback: callback, context: context)
	let data = Data(String(cString: configJson).utf8)
	guard let settings = try? JSONDecoder().decode(BusinessConfig.self, from: data),
		!settings.appId.isEmpty,
		!settings.tiktokAppId.isEmpty,
		!settings.accessToken.isEmpty
	else {
		session.finish(.failed, code: WrapperErrorCode.invalidConfiguration.rawValue, message: "invalid_configuration")
		return
	}

	runOnMain {
		// The SDK is a process-wide singleton that can only be configured once. A repeated call
		// reports the current state instead of the SDK's "-3 already attempted" error.
		if SdkState.configured {
			session.finish(currentStartedStatus())
			return
		}
		guard let config = makeConfig(settings) else {
			session.finish(.failed, code: WrapperErrorCode.configurationRejected.rawValue, message: "configuration_rejected")
			return
		}
		let deferredStart = settings.disableAutoStart == true
		TikTokBusiness.initializeSdk(config) { success, error in
			if success {
				SdkState.configured = true
				session.finish(.started)
				return
			}
			let nsError = error as NSError?
			let code = Int32(truncatingIfNeeded: nsError?.code ?? 0)
			// With disableTracking() the SDK reports -1 ("tracking not enabled"): it is configured and
			// queues events locally until StartTrack(). That is the expected deferred-start state.
			if deferredStart, code == -1 {
				SdkState.configured = true
				session.finish(.initializedTrackingDisabled, code: code, message: nsError?.localizedDescription)
				return
			}
			session.finish(.failed, code: code, message: nsError?.localizedDescription ?? "initialization_failed")
		}
	}
}

@_cdecl("ktkb_start_track")
public func ktkb_start_track() -> Bool {
	guard SdkState.configured else { return false }
	runOnMain {
		TikTokBusiness.setTrackingEnabled(true)
		TikTokBusiness.explicitlyFlush()
	}
	return true
}

@_cdecl("ktkb_set_tracking_enabled")
public func ktkb_set_tracking_enabled(_ enabled: Bool) -> Bool {
	guard SdkState.configured else { return false }
	runOnMain {
		TikTokBusiness.setTrackingEnabled(enabled)
		if enabled {
			TikTokBusiness.explicitlyFlush()
		}
	}
	return true
}

@_cdecl("ktkb_track_event")
public func ktkb_track_event(
	_ eventName: UnsafePointer<CChar>,
	_ propertiesJson: UnsafePointer<CChar>?,
	_ eventId: UnsafePointer<CChar>?
) -> Bool {
	guard SdkState.configured, let name = string(eventName) else { return false }
	var properties: [AnyHashable: Any] = [:]
	if let json = string(propertiesJson) {
		guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
			let dictionary = object as? [AnyHashable: Any]
		else {
			return false
		}
		properties = dictionary
	}
	let event = TikTokBaseEvent(eventName: name, properties: properties, eventId: string(eventId))
	TikTokBusiness.trackTTEvent(event)
	return true
}

@_cdecl("ktkb_identify")
public func ktkb_identify(
	_ externalId: UnsafePointer<CChar>?,
	_ externalUserName: UnsafePointer<CChar>?,
	_ phoneNumber: UnsafePointer<CChar>?,
	_ email: UnsafePointer<CChar>?
) -> Bool {
	guard SdkState.configured else { return false }
	let id = string(externalId)
	let userName = string(externalUserName)
	let phone = string(phoneNumber)
	let mail = string(email)
	guard id != nil || userName != nil || phone != nil || mail != nil else { return false }
	runOnMain {
		TikTokBusiness.identify(withExternalID: id, externalUserName: userName, phoneNumber: phone, email: mail)
	}
	return true
}

@_cdecl("ktkb_logout")
public func ktkb_logout() -> Bool {
	guard SdkState.configured else { return false }
	runOnMain {
		TikTokBusiness.logout()
	}
	return true
}

@_cdecl("ktkb_flush")
public func ktkb_flush() -> Bool {
	guard SdkState.configured else { return false }
	TikTokBusiness.explicitlyFlush()
	return true
}

@_cdecl("ktkb_update_access_token")
public func ktkb_update_access_token(_ accessToken: UnsafePointer<CChar>) -> Bool {
	guard SdkState.configured, let token = string(accessToken) else { return false }
	runOnMain {
		TikTokBusiness.updateAccessToken(token)
	}
	return true
}

@_cdecl("ktkb_is_initialized")
public func ktkb_is_initialized() -> Bool {
	SdkState.configured
}

@_cdecl("ktkb_is_tracking_enabled")
public func ktkb_is_tracking_enabled() -> Bool {
	SdkState.configured && TikTokBusiness.isTrackingEnabled()
}

@_cdecl("ktkb_sdk_version")
public func ktkb_sdk_version() -> UnsafeMutablePointer<CChar>? {
	duplicate(TikTokBusiness.getSDKVersion())
}

@_cdecl("ktkb_test_event_code")
public func ktkb_test_event_code() -> UnsafeMutablePointer<CChar>? {
	guard SdkState.configured, TikTokBusiness.isDebugMode() else { return nil }
	return duplicate(TikTokBusiness.getTestEventCode())
}

@_cdecl("ktkb_string_free")
public func ktkb_string_free(_ pointer: UnsafeMutablePointer<CChar>?) {
	free(pointer)
}
