# Release

This repository publishes two independent NuGet packages from `master`.

| Package | Project | Tag | Validator |
|---|---|---|---|
| `Kapusch.TikTok.iOS` (OpenSDK Share) | `src/Kapusch.TikTokApisForiOSComponents` | `vX.Y.Z` or `vX.Y.Z-rc.N` | `scripts/validate-package.sh` |
| `Kapusch.TikTok.Business.iOS` (Business SDK) | `src/Kapusch.TikTok.Business.iOS` | `business-vX.Y.Z` or `business-vX.Y.Z-rc.N` | `scripts/validate-business-package.sh` |

GitHub tag filters match the whole tag name, so `v*` never matches `business-v*`.
`publish.yml` also routes by tag prefix, so each tag builds, validates and publishes only
its own package.

## Rules

- Releases come from commits reachable from `origin/master`. There are no release branches.
- Tags are immutable. Never move or reuse a tag. Fix forward with a new version.
- Release candidates come first: `X.Y.Z-rc.N`, then `X.Y.Z` from the same or a later commit.
- The `<Version>` in each project file is the next intended version. It is also the base of
  preview versions.

## Publish a release

```sh
git switch master && git pull --ff-only
git tag business-v1.0.0-rc.1   # or v1.0.1 for the Share package
git push origin business-v1.0.0-rc.1
```

The workflow pins macos-15, Xcode 26.3 and the .NET 10.0.203 SDK and iOS workload set. It
builds the native wrapper from the checksum-locked upstream source, packs with the tag
version, validates the package and pushes it to NuGet.org with trusted publishing.

## Manual runs

`workflow_dispatch` takes a `package` choice (`share` by default) and an optional
`manual_version`:

- with a version, it publishes that version to NuGet.org, from master only;
- without a version, it publishes `<Version>-preview.<run>.<sha>` to GitHub Packages.
