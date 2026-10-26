#!/usr/bin/env bash
set -euo pipefail

# Fails when the Share and Business static archives define the same strong global symbol, which
# would break (or silently pick one of) the definitions when an app links both packages.
# Weak definitions (Swift/C++ helpers emitted in every object) are allowed to repeat.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
share_root="${1:-$repo_root/src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build/ktkshare.xcframework}"
business_root="${2:-$repo_root/src/Kapusch.TikTok.Business.iOS/Native/iOS/build/ktkbusiness.xcframework}"

strong_symbols() {
	nm -arch "$2" -m "$1" 2>/dev/null | awk '
		/\(undefined\)/ { next }
		/ non-external / { next }
		/ private external / { next }
		/ weak external / { next }
		/ external / { print $NF }
	' | LC_ALL=C sort -u
}

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
status=0
for slice in \
	"ios-arm64/libKapuschTikTokShareInterop_iphoneos.a ios-arm64/libKapuschTikTokBusinessInterop_iphoneos.a arm64" \
	"ios-arm64_x86_64-simulator/libKapuschTikTokShareInterop_simulator.a ios-arm64_x86_64-simulator/libKapuschTikTokBusinessInterop_simulator.a arm64" \
	"ios-arm64_x86_64-simulator/libKapuschTikTokShareInterop_simulator.a ios-arm64_x86_64-simulator/libKapuschTikTokBusinessInterop_simulator.a x86_64"; do
	read -r share business arch <<<"$slice"
	[[ -f "$share_root/$share" && -f "$business_root/$business" ]] || {
		echo "Missing archive for $arch: build both packages first." >&2
		exit 1
	}
	strong_symbols "$share_root/$share" "$arch" >"$work_dir/share.txt"
	strong_symbols "$business_root/$business" "$arch" >"$work_dir/business.txt"
	[[ -s "$work_dir/share.txt" && -s "$work_dir/business.txt" ]] || {
		echo "No strong symbols read for $arch; nm output format changed?" >&2
		exit 1
	}
	common="$(LC_ALL=C comm -12 "$work_dir/share.txt" "$work_dir/business.txt")"
	if [[ -n "$common" ]]; then
		echo "Strong symbol collisions between Share and Business ($arch):" >&2
		echo "$common" >&2
		status=1
	else
		echo "$arch: no strong symbol collision ($(wc -l <"$work_dir/share.txt" | tr -d ' ') Share, $(wc -l <"$work_dir/business.txt" | tr -d ' ') Business)"
	fi
done
exit "$status"
