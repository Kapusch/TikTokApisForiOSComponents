"""Fails when a tracked file contains a credential-looking value or a caller-supplied private identifier.

The tracked patterns are generic. Identifiers that must never appear in this public tree, such as
the names of private consuming applications, are not listed here: pass them at run time in
VERIFY_PUBLIC_EXTRA_PATTERNS, one case-insensitive regular expression per line (for example from a
CI secret or an untracked local file). That check is skipped when the variable is unset or empty.
Matches are reported by file name only, so the scan never echoes the values it looks for.
"""

from pathlib import Path
import os
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
patterns = [
    # A TikTok App Secret or Events API access token pasted into a sample or doc.
    re.compile(rb"(?i)(?:access_?token|app_?secret)\s*[:=]\s*[\"'][0-9a-f]{32,}[\"']"),
]

extra = [line.strip() for line in os.environ.get("VERIFY_PUBLIC_EXTRA_PATTERNS", "").splitlines()]
extra = [line for line in extra if line and not line.startswith("#")]
for index, source in enumerate(extra, start=1):
    try:
        patterns.append(re.compile(source.encode(), re.IGNORECASE))
    except re.error:
        sys.exit(f"VERIFY_PUBLIC_EXTRA_PATTERNS line {index} is not a valid regular expression")

files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).split(b"\0")
failures = []
for name in filter(None, files):
    path = root / name.decode()
    if not path.is_file():
        continue
    data = path.read_bytes()
    if any(pattern.search(data) for pattern in patterns):
        failures.append(name.decode())
if failures:
    sys.exit("Private identifier or credential found in: " + ", ".join(failures))
scope = f"{len(extra)} extra pattern(s)" if extra else "no extra patterns (VERIFY_PUBLIC_EXTRA_PATTERNS unset)"
print(f"Public tree scan passed ({len([f for f in files if f])} tracked files, {scope})")
