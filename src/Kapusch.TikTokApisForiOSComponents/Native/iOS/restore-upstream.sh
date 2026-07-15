#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../../../.." && pwd)"
LOCK_FILE="$REPO_ROOT/DependencyLocks/iOS/lockstate.txt"
UPSTREAM_DIR="$ROOT_DIR/upstream"

read -r url expected_sha filename extracted_name < <(grep -vE '^[[:space:]]*(#|$)' "$LOCK_FILE")
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$tmp_dir/$filename"
actual_sha="$(shasum -a 256 "$tmp_dir/$filename" | awk '{print $1}')"
[[ "$actual_sha" == "$expected_sha" ]] || {
	echo "SHA256 mismatch for $filename" >&2
	exit 1
}

rm -rf "$UPSTREAM_DIR"
mkdir -p "$UPSTREAM_DIR"
tar -xzf "$tmp_dir/$filename" -C "$UPSTREAM_DIR" --strip-components=1
cp "$UPSTREAM_DIR/LICENSE" "$UPSTREAM_DIR/UPSTREAM-LICENSE"
echo "Restored TikTok OpenSDK iOS 2.5.0 to: $UPSTREAM_DIR"
