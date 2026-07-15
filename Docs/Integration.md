# Integration

Reference `Kapusch.TikTok.iOS`, configure the three public TikTok values in the app `Info.plist`, and forward both open-URL and universal-link callbacks to `NativeTikTokShare`.

`ShareImagesAsync` expects two to twelve Photos local identifiers for image sharing. The host app is responsible for add-only Photos authorization and for explaining that the images remain in the photo library.

The official 2.5.0 Core and Share privacy manifests declare no collected data and no tracking. Audit the final IPA because the rest of the application can add other declarations.
