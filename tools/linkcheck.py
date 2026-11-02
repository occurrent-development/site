#!/usr/bin/env python3
"""Re-check every external URL the site shows (CARD-5); run monthly by
.github/workflows/links.yml, which opens an issue listing the dead ones.

Prints nothing and exits 0 when every live URL answers; otherwise prints a
Markdown list of the failures to stdout (the issue's body). It never fails:
the workflow is a report, not a gate, and no build depends on it. A URL
already marked dead in data/link-meta.json (`"dead": "YYYY-MM-DD"`, the
one-field edit of CARD-3) is not checked again.

Run from the repository root: python3 tools/linkcheck.py
"""

import json
import pathlib
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from wayback import META, external_urls  # noqa: E402

AGENT = "Mozilla/5.0 (compatible; occurrentdevelopment.com link check)"


def status(url):
    """The HTTP status, following redirects; HEAD first, then GET."""
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(url, method=method, headers={"User-Agent": AGENT})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status
        except urllib.error.HTTPError as e:
            if method == "HEAD" and e.code in (403, 405, 501):
                continue   # some servers refuse HEAD
            return e.code
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            return str(getattr(e, "reason", e))
    return None


def main():
    meta = json.loads(META.read_text(encoding="utf-8")) if META.exists() else {}
    dead = []
    for url in external_urls():
        if meta.get(url, {}).get("dead"):
            continue
        s = status(url)
        if not (isinstance(s, int) and s < 400):
            dead.append((url, s))
    if dead:
        print("These external links did not answer this month. Check each by hand; if one has gone for good, "
              "mark it with `\"dead\": \"YYYY-MM-DD\"` in `data/link-meta.json` (CARD-3), and its card and "
              "link will point at the Wayback copy.\n")
        for url, s in dead:
            print(f"- {url} — {s}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
