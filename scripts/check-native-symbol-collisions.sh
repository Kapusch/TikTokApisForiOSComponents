#!/usr/bin/env bash
set -euo pipefail

# Fails when the Share and Business static archives define the same strong global symbol, which
# would break (or silently pick one of) the definitions when an app links both packages.
# Weak definitions (Swift/C++ helpers emitted in every object) are allowed to repeat.
#
# Usage: check-native-symbol-collisions.sh [--with <archive>]... [share.xcframework] [business.xcframework]
#
# Each --with names another static library (.a, a static framework binary, or an .xcframework
# whose .a files are all read) that the consuming app also links. Its strong symbols are compared
# with the Business archive's, for example to catch the generic upstream symbols listed in
# Docs/Business/Integration.md section 8.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extra_archives=()
positional=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--with)
		[[ $# -ge 2 ]] || { echo "--with needs an archive path" >&2; exit 2; }
		extra_archives+=("$2")
		shift 2
		;;
	*)
		positional+=("$1")
		shift
		;;
	esac
done
share_root="${positional[0]:-$repo_root/src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build/ktkshare.xcframework}"
business_root="${positional[1]:-$repo_root/src/Kapusch.TikTok.Business.iOS/Native/iOS/build/ktkbusiness.xcframework}"

# strong_symbols <archive> [arch]: every arch when arch is omitted.
strong_symbols() {
	local arch_args=()
	[[ -n "${2:-}" ]] && arch_args=(-arch "$2")
	nm ${arch_args[@]+"${arch_args[@]}"} -m "$1" 2>/dev/null | awk '
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

if [[ ${#extra_archives[@]} -gt 0 ]]; then
	# Name-based comparison across all slices: a symbol defined on any Business slice and in the
	# other library would collide on the slice they share.
	: >"$work_dir/business-all.txt"
	while IFS= read -r archive; do
		strong_symbols "$archive" >>"$work_dir/business-all.txt"
	done < <(find "$business_root" -name '*.a' -type f)
	LC_ALL=C sort -u -o "$work_dir/business-all.txt" "$work_dir/business-all.txt"
	for extra in "${extra_archives[@]}"; do
		if [[ -d "$extra" ]]; then
			archives="$(find "$extra" -name '*.a' -type f)"
		else
			archives="$extra"
		fi
		[[ -n "$archives" ]] || { echo "No static archive found in $extra" >&2; exit 1; }
		: >"$work_dir/extra.txt"
		while IFS= read -r archive; do
			[[ -f "$archive" ]] || { echo "Missing archive: $archive" >&2; exit 1; }
			strong_symbols "$archive" >>"$work_dir/extra.txt"
		done <<<"$archives"
		LC_ALL=C sort -u -o "$work_dir/extra.txt" "$work_dir/extra.txt"
		[[ -s "$work_dir/extra.txt" ]] || { echo "No strong symbols read from $extra" >&2; exit 1; }
		common="$(LC_ALL=C comm -12 "$work_dir/business-all.txt" "$work_dir/extra.txt")"
		if [[ -n "$common" ]]; then
			echo "Strong symbol collisions between Business and $extra:" >&2
			echo "$common" >&2
			status=1
		else
			echo "$extra: no strong symbol collision with Business"
		fi
	done
fi
exit "$status"
