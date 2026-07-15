# Kapusch.TikTokApisForiOSComponents — AI Working Agreement

## Goals

- Produce a reproducible `Kapusch.TikTok.iOS` NuGet for TikTok OpenSDK Core + Share 2.5.0.
- Do not commit client keys, redirect URIs, signing material, or app-specific secrets.

## Packaging constraints

- Public OSS repo: keep docs and samples generic and not app-specific.
- The NuGet ships all required native artifacts and official privacy manifests.
- Consuming apps must never download TikTok source or native dependencies.
- This repo may restore the checksum-pinned upstream source only while building package assets.
- Preserve official privacy manifests and license notices unchanged.

## Repo layout

- `src/Kapusch.TikTokApisForiOSComponents/` — managed API, native wrapper and buildTransitive assets.
- `DependencyLocks/iOS/` — upstream version, URL and SHA-256 source of truth.
- `scripts/` — deterministic package validation.
- `Docs/` — integration and source-mode documentation.
- `samples/` — secret-free integration example.

## Safety

- Do not add dependency ingestion paths without documenting and checksum-locking them.
- Do not patch upstream TikTok sources silently.
- When package contents change, update `scripts/validate-package.sh` in the same commit.
