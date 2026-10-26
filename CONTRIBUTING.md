# Contributing

Thanks for contributing.

## Prerequisites

- macOS with Xcode 26.3 and the iOS SDK
- Swift toolchain
- .NET SDK 10 and the iOS workload
- `curl`, `unzip`, `shasum`, `nm`, `plutil`, `python3` and `xcodebuild`

## Local validation

Share package:

```sh
bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj \
  -c Release \
  -o artifacts/nuget
scripts/validate-package.sh
```

Business package:

```sh
bash src/Kapusch.TikTok.Business.iOS/Native/iOS/build.sh
dotnet pack src/Kapusch.TikTok.Business.iOS/Kapusch.TikTok.Business.iOS.csproj \
  -c Release \
  -o artifacts/nuget
scripts/validate-business-package.sh
dotnet build samples/Kapusch.TikTok.Business.iOS.Sample -c Release -r iossimulator-arm64
```

Both packages:

```sh
scripts/check-native-symbol-collisions.sh
python3 -I scripts/verify-public.py
```

`verify-public.py` checks tracked files for pasted App Secrets and checks that sample
`Info.template.plist` files keep every `Sample*` key empty. To also ban identifiers that must
not be written in this public tree, pass them at run time, one case-insensitive regular
expression per line, for example from an untracked file:

```sh
VERIFY_PUBLIC_EXTRA_PATTERNS="$(cat ~/.config/verify-public-patterns)" python3 -I scripts/verify-public.py
```

CI reads the same variable from the `VERIFY_PUBLIC_EXTRA_PATTERNS` repository secret.

For direct project consumption, see [`Docs/SourceMode.md`](Docs/SourceMode.md) and
[`Docs/Business/SourceMode.md`](Docs/Business/SourceMode.md). Releases follow
[`Docs/Release.md`](Docs/Release.md).

## Pull requests

- Keep changes focused.
- Never commit TikTok credentials or signing material.
- Update the package's lock file in `DependencyLocks/iOS/`, its checksum and its third-party
  notices together when changing an upstream SDK.
- Preserve upstream privacy manifests unchanged.

Contributions are licensed under the repository MIT license.
