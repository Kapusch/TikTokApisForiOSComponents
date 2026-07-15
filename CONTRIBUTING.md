# Contributing

Thanks for contributing.

## Prerequisites

- macOS with Xcode and the iOS SDK
- Swift toolchain
- .NET SDK 10 and the iOS workload
- `rg`, `curl`, `unzip`, `shasum`, and `xcodebuild`

## Local validation

```sh
bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj \
  -c Release \
  -o artifacts/nuget
scripts/validate-package.sh
```

For direct project consumption, see [`Docs/SourceMode.md`](Docs/SourceMode.md).

## Pull requests

- Keep changes focused.
- Never commit TikTok credentials or signing material.
- Update `DependencyLocks/iOS/lockstate.txt`, the checksum and third-party notices together when changing OpenSDK.
- Preserve upstream privacy manifests unchanged.

Contributions are licensed under the repository MIT license.
