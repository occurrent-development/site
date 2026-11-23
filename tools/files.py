#!/usr/bin/env python3
"""Check the PDFs a post offers for download (FILE-5). Part of `make`.

Reads each PDF named in data/publish.txt (the published downloads, FILE-2)
and warns, never fails, on: an author other than the site's (LAYOUT-1e); no
title; a Creator or Producer carrying a filesystem path; annotations
(comments, tracked changes); and encryption. It never rewrites a file: the
remedy is STYLE.md §7.2's, re-export or `exiftool -all= file.pdf`, before
the first commit, since the public history keeps every version (DRAFT-1).
A mismatched author is a warning, so a collaborator's paper can be offered.
Without pypdf it says so and checks nothing.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBLISH = ROOT / "data" / "publish.txt"
SITE = ROOT / "data" / "site.rktd"
PATHS = re.compile(r"(/Users/|/home/|[A-Za-z]:\\\\)")


def site_author():
    m = re.search(r'\(author \. "([^"]*)"\)', SITE.read_text(encoding="utf-8"))
    return m.group(1) if m else None


def pdfs():
    if not PUBLISH.exists():
        return []
    out = []
    for line in PUBLISH.read_text(encoding="utf-8").splitlines():
        src, _, dest = line.partition(" ")
        if "/files/" in dest and src.lower().endswith(".pdf"):
            out.append(ROOT / src)
    return out


def check(path, author, PdfReader):
    warns = []
    try:
        r = PdfReader(str(path))
    except Exception as e:  # a PDF that will not open is worth knowing about
        return [f"cannot be read ({e})"]
    if r.is_encrypted:
        return ["is encrypted"]
    info = r.metadata or {}
    a = (info.get("/Author") or "").strip()
    if author and a and a != author:
        warns.append(f"its author is {a!r}, not {author!r}")
    if not (info.get("/Title") or "").strip():
        warns.append("has no title")
    for key in ("/Creator", "/Producer"):
        v = str(info.get(key) or "")
        if PATHS.search(v):
            warns.append(f"its {key[1:]} carries a path: {v!r}")
    xmp = r.xmp_metadata
    if xmp is not None:
        raw = getattr(xmp, "stream", None)
        data = raw.get_data().decode("utf-8", "replace") if raw is not None else ""
        if PATHS.search(data):
            warns.append("its XMP carries a filesystem path")
    notes = sum(1 for p in r.pages for a in (p.get("/Annots") or [])
                if (a.get_object().get("/Subtype") in ("/Text", "/FreeText", "/Highlight", "/StrikeOut", "/Underline", "/Caret")))
    if notes:
        warns.append(f"has {notes} comment{'s' if notes > 1 else ''} or tracked change{'s' if notes > 1 else ''}")
    return warns


def main():
    files = pdfs()
    if not files:
        return 0
    try:
        from pypdf import PdfReader
    except ImportError:
        print("files: pypdf is not installed (pip install -r tools/requirements.txt); PDF metadata not checked (FILE-5)", file=sys.stderr)
        return 0
    author = site_author()
    for f in files:
        for w in check(f, author, PdfReader):
            print(f"warning: {f.relative_to(ROOT)} {w} (FILE-5; fix with exiftool -all= or a clean export, before the first commit)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
