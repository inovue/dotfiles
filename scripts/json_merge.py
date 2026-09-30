#!/usr/bin/env python3
"""Merge a managed JSON fragment into an app-owned JSON file, in place.

Apps (e.g. Claude Code) rewrite their own settings files, so those files
cannot be stow symlinks. This keeps the repo fragment authoritative for the keys
it names and leaves everything else alone:

  - objects merge recursively
  - lists become a union (fragment items appended when not already present)
  - other values from the fragment win

Prints CHANGED or UNCHANGED. Usage: json_merge.py TARGET FRAGMENT
"""
import json
import os
import sys
import tempfile


def merge(dst, src):
    if isinstance(dst, dict) and isinstance(src, dict):
        out = dict(dst)
        for k, v in src.items():
            out[k] = merge(dst[k], v) if k in dst else v
        return out
    if isinstance(dst, list) and isinstance(src, list):
        return dst + [item for item in src if item not in dst]
    return src


def main() -> int:
    target, fragment = sys.argv[1], sys.argv[2]
    with open(fragment, encoding="utf-8") as f:
        src = json.load(f)
    try:
        with open(target, encoding="utf-8") as f:
            dst = json.load(f)
    except FileNotFoundError:
        dst = {}
    out = merge(dst, src)
    if out == dst:
        print("UNCHANGED")
        return 0
    os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
    mode = os.stat(target).st_mode & 0o777 if os.path.exists(target) else 0o600
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(target)))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.chmod(tmp, mode)
    os.replace(tmp, target)
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
