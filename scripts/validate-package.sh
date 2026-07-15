#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package="${1:-$repo_root/artifacts/nuget/Kapusch.TikTok.iOS.1.0.0.nupkg}"
if [ ! -f "$package" ]; then
  echo "Package not found: $package" >&2
  exit 1
fi

entries="$(unzip -Z1 "$package")"
for expected in \
  "ktkshare.xcframework/ios-arm64/libKapuschTikTokShareInterop_iphoneos.a" \
  "ktkshare.xcframework/ios-arm64_x86_64-simulator/libKapuschTikTokShareInterop_simulator.a" \
  "privacy/TikTokOpenSDKCore.PrivacyInfo.xcprivacy" \
  "privacy/TikTokOpenShareSDK.PrivacyInfo.xcprivacy" \
  "privacy/TikTok-UPSTREAM-LICENSE" \
  "buildTransitive/Kapusch.TikTok.iOS.targets"; do
  if ! grep -Fqx "$expected" <<<"$entries"; then
    echo "Missing package entry: $expected" >&2
    exit 1
  fi
done

if grep -Eq "TikTokOpenAuthSDK|Login" <<<"$entries"; then
  echo "Unexpected TikTok Auth/Login module in Share package." >&2
  exit 1
fi

for manifest in TikTokOpenSDKCore TikTokOpenShareSDK; do
	contents="$(unzip -p "$package" "privacy/$manifest.PrivacyInfo.xcprivacy")"
	grep -Fq '<key>NSPrivacyTracking</key>' <<<"$contents"
	grep -Fq '<false/>' <<<"$contents"
done

grep -Eq 'v2\.5\.0' "$repo_root/DependencyLocks/iOS/lockstate.txt"
echo "TikTok iOS package validation passed: $package"
