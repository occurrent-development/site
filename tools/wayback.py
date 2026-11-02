#!/usr/bin/env python3
"""Ask the Wayback Machine to keep a copy of every external URL (CARD-5).
Part of `make refresh`; never run by `make` (BUILD-2) or by the reader's
browser.

The URLs are every ◊link["http…"] target in a non-draft source, and every
cited work's DOI or URL in the committed citation cache. For each one
data/link-meta.json does not yet give a `wayback` for, ask the availability
API for an existing snapshot, and failing that ask for a new one
(web.archive.org/save/…); record the snapshot's URL as `wayback`. Cards and
reference pages then show "Wayback copy" (CARD-3). A network failure, a
refusal or a rate limit is a warning and leaves the entry as it was: the
next refresh tries again. A draft's URLs are never sent: link-meta.json is
committed, and a draft's links stay private until it is published (CITE-5a).

Run from the repository root: python3 tools/wayback.py
"""

import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
META = ROOT / "data" / "link-meta.json"
CACHE = ROOT / "data" / "cite-cache.json"
SKIP_DIRS = {"public", "compiled", ".git", "node_modules", "support", "tests", "build"}
LINK = re.compile(r'◊link\[\s*"(https?://[^"]+)"')
DRAFT = re.compile(r"◊define-meta\[status\]\{\s*draft\s*\}")
AGENT = "occurrentdevelopment.com build (make refresh)"


def external_urls():
    """Every external URL a published page shows, in a stable order."""
    urls = []
    for pm in sorted(ROOT.glob("**/*.pm")):
        if SKIP_DIRS & set(pm.relative_to(ROOT).parts) or pm.name.startswith(".#"):
            continue
        text = pm.read_text(encoding="utf-8")
        if DRAFT.search(text):
            continue
        urls += LINK.findall(text)
    if CACHE.exists():
        for work in json.loads(CACHE.read_text(encoding="utf-8")).values():
            if work.get("url"):
                urls.append(work["url"])
    return list(dict.fromkeys(urls))


def get(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    return urllib.request.urlopen(req, timeout=timeout)


def existing(url):
    """The closest snapshot the Wayback Machine already holds, or None."""
    api = "https://archive.org/wayback/available?url=" + urllib.parse.quote(url, safe="")
    with get(api) as r:
        snap = json.load(r).get("archived_snapshots", {}).get("closest")
    if snap and snap.get("available") and str(snap.get("status", "200")).startswith("2"):
        return snap["url"].replace("http://", "https://", 1)
    return None


def save(url):
    """Ask for a new snapshot; its URL, or None."""
    with get("https://web.archive.org/save/" + url, timeout=180) as r:
        loc = r.headers.get("Content-Location")
        final = r.geturl()
    if loc and loc.startswith("/web/"):
        return "https://web.archive.org" + loc
    if "/web/" in final:
        return final
    return None


def main():
    meta = json.loads(META.read_text(encoding="utf-8")) if META.exists() else {}
    todo = [u for u in external_urls() if not meta.get(u, {}).get("wayback")]
    if not todo:
        print("wayback: every external URL has a snapshot")
        return
    saved = 0
    for url in todo:
        try:
            snap = existing(url) or save(url)
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"wayback: warning: {url}: {e}; try again at the next refresh")
            continue
        if not snap:
            print(f"wayback: warning: {url}: no snapshot was made; try again at the next refresh")
            continue
        meta.setdefault(url, {})["wayback"] = snap
        saved += 1
        print(f"wayback: {url} → {snap}")
        time.sleep(2)   # the save API rate-limits anonymous callers
    META.write_text(json.dumps(meta, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wayback: {saved} of {len(todo)} new snapshots recorded in data/link-meta.json")


if __name__ == "__main__":
    sys.exit(main())
