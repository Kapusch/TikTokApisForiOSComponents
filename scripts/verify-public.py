"""Fail when a tracked file contains a real-looking credential, a filled sample template or a private term.

This repository is a public, generic wrapper. The generic checks below are tracked. Terms that
must never appear (for example the names of private consuming apps) are not: they are read at run
time from an untracked source so the scanner never publishes them.

Private terms, one per line or comma-separated, matched case-insensitively as literal text:
  - the KAPUSCH_PRIVATE_TERMS environment variable (CI reads it from a repository secret);
  - the file <git dir>/info/private-terms ('#' starts a comment).
The private-term check is skipped, with a notice, when neither source provides a term.
Failures name the file and the term's position, never the term itself.

Sample Info.template.plist files must also keep every Sample* key empty: ids and the App Secret
belong in the untracked Info.plist created from the template.
"""

from __future__ import annotations

import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]

PATTERNS = {
    # A TikTok App Secret or Events API access token pasted into a sample or doc.
    "App Secret or access token": re.compile(
        rb"(?i)(?:access_?token|app_?secret)\s*[:=]\s*[\"'][0-9a-f]{32,}[\"']"
    ),
}


def split_terms(text: str) -> list[str]:
    terms = []
    for line in text.splitlines():
        line = line.split("#", 1)[0]
        terms.extend(part.strip() for part in line.split(","))
    return [term for term in terms if term]


def load_private_terms() -> list[str]:
    terms = split_terms(os.environ.get("KAPUSCH_PRIVATE_TERMS", ""))
    git_dir = subprocess.check_output(["git", "rev-parse", "--absolute-git-dir"], cwd=ROOT, text=True).strip()
    terms_file = Path(git_dir) / "info" / "private-terms"
    if terms_file.is_file():
        terms.extend(split_terms(terms_file.read_text(encoding="utf-8")))
    return list(dict.fromkeys(terms))


def filled_sample_keys(name: str, data: bytes) -> str | None:
    posix = PurePosixPath(name)
    if posix.parts[0] != "samples" or posix.name != "Info.template.plist":
        return None
    try:
        plist = plistlib.loads(data)
    except Exception:
        return "unreadable plist"
    filled = sorted(key for key, value in plist.items() if key.startswith("Sample") and value != "")
    return f"non-empty {', '.join(filled)}" if filled else None


def main() -> int:
    files = [f for f in subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0") if f]
    private = [
        (f"private term #{index}", re.compile(re.escape(term.encode()), re.IGNORECASE))
        for index, term in enumerate(load_private_terms(), start=1)
    ]
    errors = []
    for name in files:
        path = ROOT / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        for label, pattern in [*private, *PATTERNS.items()]:
            if pattern.search(data):
                errors.append(f"{name}: {label}")
        template = filled_sample_keys(name, data)
        if template:
            errors.append(f"{name}: {template}")
    if errors:
        print("Public tree scan failed:\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    if private:
        scope = f"{len(private)} private term(s)"
    else:
        scope = "no private terms configured (set KAPUSCH_PRIVATE_TERMS or .git/info/private-terms)"
    print(f"Public tree scan passed ({len(files)} tracked files, {scope})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
