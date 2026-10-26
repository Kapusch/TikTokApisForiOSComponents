#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../../../.." && pwd)"
LOCK_FILE="$REPO_ROOT/DependencyLocks/iOS/business-lockstate.txt"
UPSTREAM_DIR="$ROOT_DIR/upstream"

lock_lines="$(grep -vE '^[[:space:]]*(#|$)' "$LOCK_FILE")"
[[ "$(wc -l <<<"$lock_lines" | tr -d ' ')" == "1" ]] || {
	echo "Expected exactly one TikTok Business SDK entry in $LOCK_FILE" >&2
	exit 1
}
read -r url expected_sha filename extracted_name <<<"$lock_lines"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$tmp_dir/$filename"
actual_sha="$(shasum -a 256 "$tmp_dir/$filename" | awk '{print $1}')"
[[ "$actual_sha" == "$expected_sha" ]] || {
	echo "SHA256 mismatch for $filename: expected $expected_sha, got $actual_sha" >&2
	exit 1
}

top_level="$(tar -tzf "$tmp_dir/$filename" | head -n 1 | cut -d/ -f1)"
[[ "$top_level" == "$extracted_name" ]] || {
	echo "Unexpected archive root '$top_level' (expected '$extracted_name')" >&2
	exit 1
}

rm -rf "$UPSTREAM_DIR"
mkdir -p "$UPSTREAM_DIR"
tar -xzf "$tmp_dir/$filename" -C "$UPSTREAM_DIR" --strip-components=1
echo "Restored $extracted_name to: $UPSTREAM_DIR"
