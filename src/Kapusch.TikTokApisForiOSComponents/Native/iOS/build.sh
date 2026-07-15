#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$ROOT_DIR/KapuschTikTokShareInterop"
BUILD_DIR="$ROOT_DIR/build"
UPSTREAM_DIR="$ROOT_DIR/upstream"

if [[ ! -f "$UPSTREAM_DIR/Package.swift" ]]; then
	bash "$ROOT_DIR/restore-upstream.sh"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/privacy"
cp "$UPSTREAM_DIR/Sources/TikTokOpenSDKCore/Resources/PrivacyInfo.xcprivacy" "$BUILD_DIR/privacy/TikTokOpenSDKCore.PrivacyInfo.xcprivacy"
cp "$UPSTREAM_DIR/Sources/TikTokOpenShareSDK/Resources/PrivacyInfo.xcprivacy" "$BUILD_DIR/privacy/TikTokOpenShareSDK.PrivacyInfo.xcprivacy"
cp "$UPSTREAM_DIR/LICENSE" "$BUILD_DIR/privacy/TikTok-UPSTREAM-LICENSE"

build_slice() {
	local name="$1"
	local sdk="$2"
	local triple="$3"
	local scratch="$BUILD_DIR/spm/$name"
	local output="$BUILD_DIR/libKapuschTikTokShareInterop_$name.a"

	swift build --package-path "$PACKAGE_DIR" --scratch-path "$scratch" -c release --sdk "$sdk" --triple "$triple"
	local objects=()
	while IFS= read -r object; do
		objects+=("$object")
	done < <(find "$scratch" -path '*/release/*.build/*.o' \( \
		-path '*KapuschTikTokShareInterop.build*' -o \
		-path '*TikTokOpenSDKCore.build*' -o \
		-path '*TikTokOpenShareSDK.build*' \) -print)
	[[ "${#objects[@]}" -gt 0 ]] || { echo "No Swift objects found for $name" >&2; exit 1; }
	libtool -static -o "$output" "${objects[@]}"
}

build_slice iphoneos "$(xcrun --sdk iphoneos --show-sdk-path)" arm64-apple-ios15.0
build_slice simulator-arm64 "$(xcrun --sdk iphonesimulator --show-sdk-path)" arm64-apple-ios15.0-simulator
build_slice simulator-x64 "$(xcrun --sdk iphonesimulator --show-sdk-path)" x86_64-apple-ios15.0-simulator

lipo -create \
	"$BUILD_DIR/libKapuschTikTokShareInterop_simulator-arm64.a" \
	"$BUILD_DIR/libKapuschTikTokShareInterop_simulator-x64.a" \
	-output "$BUILD_DIR/libKapuschTikTokShareInterop_simulator.a"

xcodebuild -create-xcframework \
	-library "$BUILD_DIR/libKapuschTikTokShareInterop_iphoneos.a" -headers "$PACKAGE_DIR/include" \
	-library "$BUILD_DIR/libKapuschTikTokShareInterop_simulator.a" -headers "$PACKAGE_DIR/include" \
	-output "$BUILD_DIR/ktkshare.xcframework"

echo "Built: $BUILD_DIR/ktkshare.xcframework"
