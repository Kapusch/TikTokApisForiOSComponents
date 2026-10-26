#!/usr/bin/env bash
set -euo pipefail

# Builds ktkbusiness.xcframework: the thin ktkb_* Swift facade plus the TikTok Business SDK
# (Objective-C core + Swift StoreKit 2 observer) compiled from the checksum-locked upstream
# source with the local Xcode toolchain, merged into one static library per slice.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$ROOT_DIR/KapuschTikTokBusinessInterop"
BUILD_DIR="$ROOT_DIR/build"
UPSTREAM_DIR="$ROOT_DIR/upstream"
LIB_NAME="KapuschTikTokBusinessInterop"

if [[ ! -f "$UPSTREAM_DIR/Package.swift" ]]; then
	bash "$ROOT_DIR/restore-upstream.sh"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/privacy"
# The upstream SwiftPM package declares no resources, so its privacy manifest lives at the
# repository root (the release xcframework ships the same file at the framework root).
cp "$UPSTREAM_DIR/PrivacyInfo.xcprivacy" "$BUILD_DIR/privacy/TikTokBusinessSDK.PrivacyInfo.xcprivacy"
cp "$UPSTREAM_DIR/LICENSE" "$BUILD_DIR/privacy/TikTokBusinessSDK-UPSTREAM-LICENSE"

build_slice() {
	local name="$1"
	local sdk="$2"
	local triple="$3"
	local scratch="$BUILD_DIR/spm/$name"
	local output="$BUILD_DIR/lib${LIB_NAME}_$name.a"

	swift build --package-path "$PACKAGE_DIR" --scratch-path "$scratch" -c release --sdk "$sdk" --triple "$triple"
	local objects=()
	while IFS= read -r object; do
		objects+=("$object")
	done < <(find "$scratch" -path '*/release/*.build/*.o' \( \
		-path "*/${LIB_NAME}.build/*" -o \
		-path '*/TikTokBusinessSDKCore.build/*' -o \
		-path '*/TikTokBusinessSDK.build/*' \) -print | LC_ALL=C sort)
	local wrapper_count core_count swift_count
	wrapper_count="$(printf '%s\n' "${objects[@]}" | grep -c "/${LIB_NAME}.build/" || true)"
	core_count="$(printf '%s\n' "${objects[@]}" | grep -c '/TikTokBusinessSDKCore.build/' || true)"
	swift_count="$(printf '%s\n' "${objects[@]}" | grep -c '/TikTokBusinessSDK.build/' || true)"
	if [[ "$wrapper_count" -lt 1 || "$core_count" -lt 1 || "$swift_count" -lt 1 ]]; then
		echo "Missing objects for $name (wrapper=$wrapper_count core=$core_count swift=$swift_count)" >&2
		exit 1
	fi
	libtool -static -no_warning_for_no_symbols -o "$output" "${objects[@]}"
}

build_slice iphoneos "$(xcrun --sdk iphoneos --show-sdk-path)" arm64-apple-ios15.0
build_slice simulator-arm64 "$(xcrun --sdk iphonesimulator --show-sdk-path)" arm64-apple-ios15.0-simulator
build_slice simulator-x64 "$(xcrun --sdk iphonesimulator --show-sdk-path)" x86_64-apple-ios15.0-simulator

lipo -create \
	"$BUILD_DIR/lib${LIB_NAME}_simulator-arm64.a" \
	"$BUILD_DIR/lib${LIB_NAME}_simulator-x64.a" \
	-output "$BUILD_DIR/lib${LIB_NAME}_simulator.a"

xcodebuild -create-xcframework \
	-library "$BUILD_DIR/lib${LIB_NAME}_iphoneos.a" -headers "$PACKAGE_DIR/include" \
	-library "$BUILD_DIR/lib${LIB_NAME}_simulator.a" -headers "$PACKAGE_DIR/include" \
	-output "$BUILD_DIR/ktkbusiness.xcframework"

echo "Built: $BUILD_DIR/ktkbusiness.xcframework"
