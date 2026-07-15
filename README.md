# Kapusch.TikTok.iOS

.NET iOS interop and deterministic native packaging for TikTok OpenSDK 2.5.0 Core + Share.

The NuGet contains the native XCFramework and official privacy manifests. Consumer builds never invoke SwiftPM or download TikTok sources.

Build native assets, then pack:

```bash
bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj -c Release
```

The consuming app must configure `TikTokClientKey`, `TikTokRedirectURI`, `TikTokURLScheme`, the registered URL scheme and the associated domain required by its approved TikTok application.

## Repository guides

- [`Docs/Integration.md`](Docs/Integration.md) — application integration contract.
- [`Docs/SourceMode.md`](Docs/SourceMode.md) — consume a sibling checkout without package-time downloads.
- [`samples/`](samples/) — secret-free minimal integration notes.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local validation and dependency-update rules.

Tags reachable from `master` publish to NuGet.org. Manual runs without a version publish a preview package to GitHub Packages.
