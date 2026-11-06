#!/usr/bin/env python3
"""Classify figures, and each panel of a ◊panels (IMG-9), for dark mode with
InvertOrNot (IMG-4). Part of `make refresh`.

Each raster figure is looked up once by SHA-1 (nothing uploaded); if the
service does not know it, the file is uploaded, unless its licence is
`permission`: InvertOrNot may keep uploaded images, and only images that
are yours or openly licensed are sent. Results are cached in
data/invert.json by SHA-256, so the reader's browser never calls the
service. A network failure keeps the cache as it is; it never breaks a build.
"""

import datetime
import hashlib
import json
import pathlib
import re
import sys
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "invert.json"
API = "https://invertornot.com/api"
SKIP_DIRS = {"public", "compiled", ".git", "node_modules", "tests", "support"}  # BUILD-3a: an essay's support/ is never read
FIGURE = re.compile(r'◊figure\[\s*"([^"]+)"([^\]]*)\]', re.S)
PANELS = re.compile(r'◊panels\[([^\]]*)\]')                    # IMG-9: the figure, which has no source
PANEL = re.compile(r'◊panel\[\s*"([^"]+)"([^\]]*)\]', re.S)     # one panel, classified on its own
TYPES = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp", ".pdf": "application/pdf"}
LICENCE = re.compile(r'#:licence\s+"([^"]+)"')


def figures():
    for pm in sorted(ROOT.glob("**/*.pm")):
        if SKIP_DIRS & set(pm.relative_to(ROOT).parts):
            continue
        if pm.name.startswith(".#") or not pm.is_file():   # Emacs lock files (dangling symlinks)
            continue
        text = pm.read_text(encoding="utf-8")
        found = [(src, LICENCE.search(rest)) for src, rest in FIGURE.findall(text)]
        # IMG-9: a panel without a #:licence of its own has its ◊panels' licence
        heads = [(m.start(), LICENCE.search(m.group(1))) for m in PANELS.finditer(text)]
        for m in PANEL.finditer(text):
            outer = next((lic for start, lic in reversed(heads) if start < m.start()), None)
            found.append((m.group(1), LICENCE.search(m.group(2)) or outer))
        for src, m in found:
            path = (pm.parent / src).resolve()
            if path.suffix.lower() in (".svg",) or not path.exists():
                continue
            yield path, (m.group(1) if m else None)


def post(endpoint, body, content_type):
    req = urllib.request.Request(f"{API}/{endpoint}", data=body, method="POST",
                                 headers={"Content-Type": content_type, "Accept": "application/json",
                                          "User-Agent": "occurrentdevelopment.com build (make refresh)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def by_sha1(sha1):
    result = post("sha1", json.dumps([sha1]).encode(), "application/json")[0]
    return None if result.get("error") else result["invert"]


def by_upload(path):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"files\"; filename=\"{path.name}\"\r\n"
            f"Content-Type: {TYPES.get(path.suffix.lower(), 'application/octet-stream')}\r\n\r\n").encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    result = post("file", body, f"multipart/form-data; boundary={boundary}")[0]
    if result.get("error"):
        raise RuntimeError(result["error"])
    return result["invert"]


def main():
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    changed = False
    for path, licence in figures():
        data = path.read_bytes()
        sha256 = hashlib.sha256(data).hexdigest()
        rel = path.relative_to(ROOT).as_posix()
        if sha256 in cache:
            continue
        try:
            invert = by_sha1(hashlib.sha1(data).hexdigest())
            if invert is None:
                if licence == "permission":
                    print(f"invert: {rel} not classified (licence: permission; not uploaded). Use #:invert if needed.")
                    continue
                invert = by_upload(path)
        except Exception as e:  # network or service trouble: keep going
            print(f"invert: {rel} not classified ({e}); the cache is unchanged")
            continue
        cache[sha256] = {"invert": bool(invert), "file": rel, "checked": datetime.date.today().isoformat()}
        changed = True
        print(f"invert: {rel} → {'invert' if invert else 'dim'}")
    if changed or not CACHE.exists():
        CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
