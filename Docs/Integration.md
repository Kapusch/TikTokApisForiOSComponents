# Integration

Reference `Kapusch.TikTok.iOS`, configure the three public TikTok values in the app `Info.plist`, and forward both open-URL and universal-link callbacks to `NativeTikTokShare`.
The wrapper rejects URLs that do not match the configured `TikTokURLScheme` or
`TikTokRedirectURI`; host applications should still route only those URLs to the
TikTok handler.

`ShareImagesAsync` expects one to twelve Photos local identifiers for image sharing.
TikTok OpenSDK 2.5.0 does not accept file paths or in-memory image data for this
flow. The host app is responsible for add-only Photos authorization and for
explaining that the images remain in the photo library.

OpenSDK does not always return a callback when the user switches back to the host
app without completing or cancelling in TikTok. A host that waits for
`ShareImagesAsync` should:

1. observe that it actually entered the background after sending the request;
2. observe the subsequent return to the active state;
3. leave a short grace period for the official callback;
4. call `NativeTikTokShare.AbandonPendingShare()` if the request is still pending.

Abandoning completes the pending task once with `Cancelled` and the stable error
code `returned_without_callback`. A late OpenSDK callback is ignored. Do not call
this API for an activation event that was not preceded by the share handoff
entering the background.

The official 2.5.0 Core and Share privacy manifests declare no collected data and no tracking. Audit the final IPA because the rest of the application can add other declarations.
