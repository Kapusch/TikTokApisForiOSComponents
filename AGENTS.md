# Kapusch.TikTokApisForiOSComponents — AI Working Agreement

## Goals

- Produce a reproducible `Kapusch.TikTok.iOS` NuGet for TikTok OpenSDK Core + Share 2.5.0.
- Produce a reproducible `Kapusch.TikTok.Business.iOS` NuGet for the TikTok Business SDK
  (App Events SDK) 1.7.2.
- Do not commit client keys, redirect URIs, App IDs, App Secrets, signing material, or
  app-specific secrets.

## Packaging constraints

- Public OSS repo: keep docs and samples generic and not app-specific.
- Each NuGet ships all required native artifacts and official privacy manifests.
- Consuming apps must never download TikTok source or native dependencies.
- This repo may restore the checksum-pinned upstream sources only while building package assets.
- Preserve official privacy manifests and license notices unchanged.
- The two packages are independent. Never change the Share package contents or behaviour
  as a side effect of Business work (and vice versa).

## Repo layout

- `src/Kapusch.TikTokApisForiOSComponents/` — Share package: managed API, native wrapper and buildTransitive assets.
- `src/Kapusch.TikTok.Business.iOS/` — Business package: managed API, native `ktkb_*` facade and buildTransitive assets.
- `DependencyLocks/iOS/lockstate.txt` (Share) and `DependencyLocks/iOS/business-lockstate.txt` (Business) — upstream version, URL and SHA-256 source of truth.
- `scripts/` — deterministic package validation, native symbol collision check and public-tree scan.
- `Docs/` — Share integration and source mode, `Docs/Business/` for the Business package, `Docs/Release.md` for both.
- `samples/` — secret-free integration examples.

## Safety

- Do not add dependency ingestion paths without documenting and checksum-locking them.
- Do not patch upstream TikTok sources silently.
- When package contents change, update the matching validator (`scripts/validate-package.sh`
  or `scripts/validate-business-package.sh`) in the same commit.
- Native exports use `ktk_` (Share) and `ktkb_` (Business) prefixes and are consumed with
  `LibraryImport("__Internal")`, never `NativeLibrary.GetExport`.
- The Business wrapper must not touch the SDK before `InitializeAsync`; consumers gate that call on consent.
