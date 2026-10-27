#!/usr/bin/env bash
set -euo pipefail

# Deterministic checks for the Kapusch.TikTok.Business.iOS package.
# The Share package keeps its own checks in scripts/validate-package.sh.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$repo_root/src/Kapusch.TikTok.Business.iOS"
managed_source="$project_dir/TikTokBusiness/TikTokBusinessSdk.iOS.cs"
swift_source="$project_dir/Native/iOS/KapuschTikTokBusinessInterop/Sources/KapuschTikTokBusinessInterop/Interop.swift"
lock_file="$repo_root/DependencyLocks/iOS/business-lockstate.txt"
upstream_dir="$project_dir/Native/iOS/upstream"
package_id="Kapusch.TikTok.Business.iOS"

package="${1:-}"
if [[ -z "$package" ]]; then
	shopt -s nullglob
	candidates=("$repo_root"/artifacts/nuget/"$package_id".[0-9]*.nupkg)
	shopt -u nullglob
	[[ "${#candidates[@]}" -eq 1 ]] || {
		echo "Pass the package path, or keep exactly one $package_id nupkg in artifacts/nuget (found ${#candidates[@]})." >&2
		exit 1
	}
	package="${candidates[0]}"
fi
[[ -f "$package" ]] || { echo "Package not found: $package" >&2; exit 1; }

fail() {
	echo "Business package validation failed: $*" >&2
	exit 1
}

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# 1. Managed interop invariants: static __Internal imports only, and the C# and Swift export sets match.
grep -Fq "NativeLibrary.GetExport" "$managed_source" \
	&& fail "TikTokBusinessSdk must use static __Internal imports so iOS retains its native symbols."
grep -Eo 'LibraryImport\("__Internal", EntryPoint = "ktkb_[a-z_]+"' "$managed_source" \
	| grep -Eo 'ktkb_[a-z_]+' | LC_ALL=C sort -u >"$work_dir/managed.txt"
grep -Eo '@_cdecl\("ktkb_[a-z_]+"\)' "$swift_source" \
	| grep -Eo 'ktkb_[a-z_]+' | LC_ALL=C sort -u >"$work_dir/swift.txt"
[[ -s "$work_dir/managed.txt" ]] || fail "no ktkb_* imports found in $managed_source"
diff -u "$work_dir/swift.txt" "$work_dir/managed.txt" >/dev/null \
	|| fail "C# imports and Swift exports differ: $(diff "$work_dir/swift.txt" "$work_dir/managed.txt" | tr '\n' ' ')"
grep -Eq '@_cdecl\("ktk_' "$swift_source" && fail "Business exports must use the ktkb_ prefix (ktk_ belongs to the Share package)."

# 2. Dependency lock: one entry, pinned version, and the restored upstream matches it.
lock_entries="$(grep -vE '^[[:space:]]*(#|$)' "$lock_file")"
[[ "$(wc -l <<<"$lock_entries" | tr -d ' ')" == "1" ]] || fail "expected one entry in $lock_file"
read -r lock_url lock_sha _ lock_dir <<<"$lock_entries"
[[ "$lock_url" =~ ^https://codeload\.github\.com/tiktok/tiktok-business-ios-sdk/tar\.gz/refs/tags/([0-9]+\.[0-9]+\.[0-9]+)$ ]] \
	|| fail "unexpected upstream URL: $lock_url"
lock_version="${BASH_REMATCH[1]}"
[[ "$lock_sha" =~ ^[0-9a-f]{64}$ ]] || fail "lock SHA-256 is malformed"
[[ "$lock_dir" == "tiktok-business-ios-sdk-$lock_version" ]] || fail "lock directory does not match version $lock_version"
if [[ -f "$upstream_dir/TikTokBusinessSDK/Core/TikTokBusinessSDKMacros.h" ]]; then
	grep -Fq "#define SDK_VERSION @\"$lock_version\"" "$upstream_dir/TikTokBusinessSDK/Core/TikTokBusinessSDKMacros.h" \
		|| fail "restored upstream is not TikTok Business SDK $lock_version"
fi

# 3. Package layout.
entries="$(unzip -Z1 "$package")"
for expected in \
	"$package_id.nuspec" \
	"buildTransitive/$package_id.props" \
	"buildTransitive/$package_id.targets" \
	"ktkbusiness.xcframework/Info.plist" \
	"ktkbusiness.xcframework/ios-arm64/libKapuschTikTokBusinessInterop_iphoneos.a" \
	"ktkbusiness.xcframework/ios-arm64_x86_64-simulator/libKapuschTikTokBusinessInterop_simulator.a" \
	"privacy/TikTokBusinessSDK.PrivacyInfo.xcprivacy" \
	"privacy/TikTokBusinessSDK-UPSTREAM-LICENSE" \
	"THIRD_PARTY_NOTICES.md" \
	"nuget-readme.md"; do
	grep -Fqx "$expected" <<<"$entries" || fail "missing package entry: $expected"
done
grep -Eq "^lib/net10\.0-ios[0-9.]+/$package_id\.dll\$" <<<"$entries" || fail "missing managed assembly"
grep -Eq '(^|/)ktkshare\.xcframework/|TikTokOpen|Kapusch\.TikTok\.iOS\.(dll|props|targets)' <<<"$entries" \
	&& fail "Share package content leaked into the Business package"
grep -Eq '\.framework/|\.dylib$|Native/iOS/upstream/|\.swiftmodule' <<<"$entries" \
	&& fail "unexpected dynamic framework, dylib, upstream source or Swift module in the package"

nuspec="$(unzip -p "$package" "$package_id.nuspec")"
grep -Fq "<id>$package_id</id>" <<<"$nuspec" || fail "nuspec id is not $package_id"

# 4. Privacy manifest: valid, official (unchanged when the upstream source is available), and wired.
unzip -p "$package" "privacy/TikTokBusinessSDK.PrivacyInfo.xcprivacy" >"$work_dir/PrivacyInfo.xcprivacy"
plutil -lint "$work_dir/PrivacyInfo.xcprivacy" >/dev/null || fail "privacy manifest is not a valid plist"
grep -Fq "NSPrivacyAccessedAPICategoryUserDefaults" "$work_dir/PrivacyInfo.xcprivacy" \
	|| fail "privacy manifest does not look like the official TikTok Business SDK manifest"
if [[ -f "$upstream_dir/PrivacyInfo.xcprivacy" ]]; then
	cmp -s "$work_dir/PrivacyInfo.xcprivacy" "$upstream_dir/PrivacyInfo.xcprivacy" \
		|| fail "packaged privacy manifest differs from the upstream file"
fi
targets="$(unzip -p "$package" "buildTransitive/$package_id.targets")"
grep -Fq 'LogicalName="TikTokBusinessSDK_Privacy.bundle/PrivacyInfo.xcprivacy"' <<<"$targets" \
	|| fail "targets no longer bundle the privacy manifest"
for metadata in '<ForceLoad>true</ForceLoad>' '<IsCxx>true</IsCxx>' '<Kind>Static</Kind>'; do
	grep -Fq "$metadata" <<<"$targets" || fail "targets lost NativeReference metadata $metadata"
done

# 5. Native archives: every slice exports the facade, carries the SDK and nothing from the Share package.
for slice in \
	"ios-arm64/libKapuschTikTokBusinessInterop_iphoneos.a:arm64" \
	"ios-arm64_x86_64-simulator/libKapuschTikTokBusinessInterop_simulator.a:arm64" \
	"ios-arm64_x86_64-simulator/libKapuschTikTokBusinessInterop_simulator.a:x86_64"; do
	path="${slice%%:*}"
	arch="${slice##*:}"
	archive="$work_dir/$(basename "$path")"
	[[ -f "$archive" ]] || unzip -p "$package" "ktkbusiness.xcframework/$path" >"$archive"
	nm -arch "$arch" -gU "$archive" 2>/dev/null | awk 'NF >= 3 { print $NF }' | LC_ALL=C sort -u >"$work_dir/symbols.txt"
	grep -E '^_ktkb_[a-z_]+$' "$work_dir/symbols.txt" | sed 's/^_//' >"$work_dir/exported.txt"
	diff -u "$work_dir/managed.txt" "$work_dir/exported.txt" >/dev/null \
		|| fail "$path ($arch) does not export exactly the managed ktkb_* entry points"
	for class in TikTokBusiness TikTokConfig TikTokBaseEvent TikTokStoreKitObserver; do
		grep -Fqx "_OBJC_CLASS_\$_$class" "$work_dir/symbols.txt" \
			|| fail "$path ($arch) is missing Objective-C class $class"
	done
	grep -Eq '^_ktk_tiktok_|^_OBJC_CLASS_\$_TikTokOpen' "$work_dir/symbols.txt" \
		&& fail "$path ($arch) contains Share package symbols"
done

echo "TikTok Business iOS package validation passed: $package (TikTok Business SDK $lock_version)"
