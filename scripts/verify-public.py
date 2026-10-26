"""Fails when a tracked file contains a private application identifier or a credential-looking value.

The patterns are written with hex escapes so this scanner does not itself contain the names it bans.
"""

from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
patterns = [
    # Private application and company names.
    re.compile(rb"(?i)\x62\x6c\x6f\x6f\x6d[ &_-]*(?:\x61\x6e\x64[ _-]*)?(?:\x66\x6c\x79|\x79)"),
    # A TikTok App Secret or Events API access token pasted into a sample or doc.
    re.compile(rb"(?i)(?:access_?token|app_?secret)\s*[:=]\s*[\"'][0-9a-f]{32,}[\"']"),
]
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
print(f"Public tree scan passed ({len([f for f in files if f])} tracked files)")
