# TikTok Business iOS sample

Minimal UIKit app that consumes `Kapusch.TikTok.Business.iOS` in source mode. It
initializes the SDK only after the user taps the consent button, then asks for App
Tracking Transparency, tracks `ViewContent` and a `StartTrial` with an event id, and
shows the Events Manager test event code (debug mode).

## Run locally

1. Build the native assets: `bash src/Kapusch.TikTok.Business.iOS/Native/iOS/build.sh`.
2. Build the sample once: it copies `Info.template.plist` to the untracked `Info.plist`.
3. Fill `SampleTikTokBusinessAppId` (numeric App Store ID), `SampleTikTokBusinessTikTokAppId`
   (one or several comma-separated TikTok App IDs) and `SampleTikTokBusinessAccessToken`
   (App Secret) in `Info.plist`. Never commit that file.
4. Run on a simulator or device:

   ```sh
   dotnet build samples/Kapusch.TikTok.Business.iOS.Sample -c Debug -r iossimulator-arm64 -t:Run
   ```

5. Enter the displayed test event code in Events Manager, Test Events, to watch the events.

Without the three values the sample still launches and reports that it is not configured.
CI builds it for the simulator as a link smoke test.
