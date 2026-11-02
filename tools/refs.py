#!/usr/bin/env python3
"""Refresh the citation caches (BUILD-3, CITE-5). Part of `make refresh`.

1. Collect every key cited in the sources (◊cite["key"]).
2. Write refs/refs.bib with just those entries, taken from the Zotero
   (Better BibTeX) export named by $ZOTERO_BIB, else kept from the existing
   refs.bib. Private fields (abstracts, notes, file paths, keywords) are
   dropped: the repository is public.
3. Run pandoc --citeproc with the Chicago notes style and write, per key,
   the full note, the short note and the bibliography entry, plus DOI/URL,
   bibliography order and the facts /bibliography sorts by (title, authors,
   year, type; BIB-4), to data/cite-cache.json.
4. Copy each cited work's cover (BIB-7): a photograph of your own copy,
   attached to the Zotero item as cover.jpg, downsized to refs/covers/<key>.jpg.

Fragments are stored as X-expressions in JSON (["em", {}, "text"]), so the
Racket build never parses HTML.
"""

import html
import html.parser
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
BIB = ROOT / "refs" / "refs.bib"
# Citations used only by drafts go here instead: gitignored, so a draft's
# references never reach the public repository before the draft does.
LOCAL_BIB = ROOT / "refs" / "refs.local.bib"
LOCAL_CACHE = ROOT / "data" / "cite-cache.local.json"
CSL = ROOT / "refs" / "chicago-notes-bibliography.csl"
CACHE = ROOT / "data" / "cite-cache.json"
SKIP_DIRS = {"public", "compiled", ".git", "node_modules", "support"}  # BUILD-3a: an essay's support/ is never read

PRIVATE_FIELDS = {
    "abstract", "file", "keywords", "annotation", "annote", "note", "copyright",
    "urldate", "ids", "mendeley-tags", "groups", "owner", "timestamp",
}
# A citation is ◊cite["key" …], ◊q["key" …]{…} (BIB-9), or #:cite "key" on a
# block quotation or epigraph, each with an optional #:loc.
CITE = re.compile(r'◊(?:cite|q)\[\s*"([^"]+)"([^\]]*)\]', re.S)
BLOCK = re.compile(r'◊(?:blockquote|epigraph)\[([^\]]*#:cite[^\]]*)\]', re.S)
BLOCK_KEY = re.compile(r'#:cite\s+"([^"]+)"')
LOC = re.compile(r'#:loc\s+"([^"]*)"')
COVERS = ROOT / "refs" / "covers"
# Covers of works only drafts cite stay local too, as their entries do (CITE-5a).
LOCAL_COVERS = ROOT / "refs" / "covers.local"
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".tif", ".tiff", ".heic", ".heif"}
COVER_SIDE = 800


def norm_loc(loc):
    return re.sub(r"\s+", " ", loc).strip() if loc else ""


DRAFT = re.compile(r"◊define-meta\[status\]\{\s*draft\s*\}")


def cited():
    """Ordered {key: [locator, ...]} for every ◊cite in the sources ("" = none),
    and the set of (key, locator) forms that some non-draft source uses."""
    found = {}
    public = set()
    for path in sorted(ROOT.glob("**/*.pm")):
        if SKIP_DIRS & set(path.relative_to(ROOT).parts):
            continue
        text = path.read_text(encoding="utf-8")
        draft = bool(DRAFT.search(text))
        blocks = [(m.group(1), rest) for rest in BLOCK.findall(text) for m in [BLOCK_KEY.search(rest)] if m]
        for key, rest in CITE.findall(text) + blocks:
            m = LOC.search(rest)
            loc = norm_loc(m.group(1) if m else "")
            locs = found.setdefault(key, [])
            if loc not in locs:
                locs.append(loc)
            if not draft:
                public.add((key, loc))
    return found, public


def split_entries(text):
    """Map key -> raw entry text for a BibTeX file."""
    entries = {}
    for chunk in re.split(r"\n(?=@)", "\n" + text):
        m = re.match(r"\s*@(\w+)\s*\{\s*([^,\s]+)\s*,", chunk)
        if m and m.group(1).lower() not in ("comment", "string", "preamble"):
            entries[m.group(2)] = chunk.strip()
    return entries


def parse_entry(entry):
    """Return (type, key, [(field, raw value)]) for one BibTeX entry."""
    m = re.match(r"\s*@(\w+)\s*\{\s*([^,\s]+)\s*,", entry)
    kind, key, i = m.group(1), m.group(2), m.end()
    fields = []
    while True:
        while i < len(entry) and entry[i] in " \t\r\n,":
            i += 1
        if i >= len(entry) or entry[i] == "}":
            break
        eq = entry.index("=", i)
        name = entry[i:eq].strip()
        i = eq + 1
        while entry[i] in " \t\r\n":
            i += 1
        start = i
        if entry[i] in "{\"":
            close = "}" if entry[i] == "{" else "\""
            depth = 0
            while True:
                c = entry[i]
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                if close == "}" and depth == 0 and c == "}":
                    break
                if close == "\"" and c == "\"" and i > start and depth == 0:
                    break
                i += 1
            i += 1
        else:
            while entry[i] not in ",}\n":
                i += 1
        fields.append((name, entry[start:i].strip()))
    return kind, key, fields


def strip_private(entry):
    kind, key, fields = parse_entry(entry)
    kept = [f"  {n} = {v}" for n, v in fields if n.lower() not in PRIVATE_FIELDS]
    return f"@{kind}{{{key},\n" + ",\n".join(kept) + "\n}"


def write_bib(keys, local_keys=()):
    """Write refs.bib (and refs.local.bib); return the raw entries read,
    `file` fields and all, for the covers."""
    zotero = os.environ.get("ZOTERO_BIB")
    sources = {}
    for f in (BIB, LOCAL_BIB):
        if f.exists():
            sources.update(split_entries(f.read_text(encoding="utf-8")))
    if zotero:
        sources.update(split_entries(pathlib.Path(zotero).expanduser().read_text(encoding="utf-8")))
    else:
        print("refs: ZOTERO_BIB not set; keeping entries already in refs/refs.bib")
    missing = [k for k in list(keys) + list(local_keys) if k not in sources]
    if missing:
        sys.exit("refs: no entry for " + ", ".join(missing) + " (check the key, or that Zotero has exported it)")
    head = "% Generated by `make refresh` from the Zotero export; edit in Zotero.\n\n"
    BIB.write_text(head + "\n\n".join(strip_private(sources[k]) for k in keys) + "\n", encoding="utf-8")
    print(f"refs: {len(keys)} entries in refs/refs.bib")
    if local_keys:
        LOCAL_BIB.write_text("% Cited only by drafts; not committed.\n\n"
                             + "\n\n".join(strip_private(sources[k]) for k in local_keys) + "\n",
                             encoding="utf-8")
        print(f"refs: {len(local_keys)} entries cited only by drafts, in refs/refs.local.bib (not committed)")
    elif LOCAL_BIB.exists():
        LOCAL_BIB.unlink()
    return sources if zotero else None


def attachments(entry):
    """The absolute paths in a Better BibTeX `file` field, `;`-separated."""
    raw = next((v for n, v in parse_entry(entry)[2] if n.lower() == "file"), None)
    if not raw:
        return []
    raw = raw.strip()
    if raw[:1] in "{\"":
        raw = raw[1:-1]
    return [pathlib.Path(p.strip()) for p in re.split(r"(?<!\\);", raw) if p.strip()]


def cover_source(key, entry):
    """The attachment that is the work's cover (BIB-7): the image whose name
    contains `cover`, else the only image; None when there is none. Two or
    more images with no cover among them, or a HEIC, is an error."""
    images = [p for p in attachments(entry) if p.suffix.lower() in IMAGE_EXT]
    named = [p for p in images if "cover" in p.name.lower()]
    if len(named) > 1:
        sys.exit(f"refs: {key} has {len(named)} attachments named cover: "
                 + ", ".join(str(p) for p in named) + "; keep one")
    if not named and len(images) > 1:
        sys.exit(f"refs: {key} has {len(images)} image attachments and none is named cover: "
                 + ", ".join(str(p) for p in images) + "; rename the photograph of your copy cover.jpg")
    src = (named or images or [None])[0]
    if src and src.suffix.lower() in (".heic", ".heif"):
        sys.exit(f"refs: {key}: {src} is HEIC; export the photograph as JPEG (cover.jpg) and attach that instead")
    return src


def shown(path):
    """A path for a message: relative to the repository when it is inside it."""
    try:
        return path.relative_to(ROOT)
    except ValueError:
        return path


def write_cover(src, dest):
    """A JPEG copy, longest side COVER_SIDE px, of a cover photograph."""
    from PIL import Image, ImageOps
    with Image.open(src) as img:
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.thumbnail((COVER_SIDE, COVER_SIDE), Image.LANCZOS)
        dest.parent.mkdir(parents=True, exist_ok=True)
        img.save(dest, "JPEG", quality=85, optimize=True, progressive=True)


def refresh_covers(sources, public_keys, local_keys):
    """BIB-7: refs/covers/<key>.jpg for every cited work with a cover in
    Zotero, refs/covers.local/ for works only drafts cite. A copy whose
    attachment has gone is deleted, with a warning. Without the Zotero
    export (no ZOTERO_BIB) the covers are left as they are."""
    if sources is None:
        print("refs: ZOTERO_BIB not set; covers left as they are")
        return
    for folder, keys in ((COVERS, public_keys), (LOCAL_COVERS, local_keys)):
        wanted = set()
        for k in keys:
            src = cover_source(k, sources[k])
            if src is None:
                continue
            if not src.exists():
                print(f"refs: warning: {k}: the cover attachment {src} is missing from Zotero's storage")
                continue
            dest = folder / f"{k}.jpg"
            # re-encode only when the photograph is newer than the copy
            if not dest.exists() or src.stat().st_mtime > dest.stat().st_mtime:
                write_cover(src, dest)
                print(f"refs: cover for {k} → {shown(dest)}")
            wanted.add(dest.name)
        if folder.exists():
            for old in folder.glob("*.jpg"):
                if old.name not in wanted:
                    old.unlink()
                    print(f"refs: warning: {old.stem} has no cover in Zotero any more (or is no longer cited "
                          f"there); deleted {shown(old)}")


class XExpr(html.parser.HTMLParser):
    """HTML fragment -> nested lists, keeping only inline formatting."""

    KEEP = {"em", "i", "strong", "b", "span", "a", "sup", "sub"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = [["frag", {}]]

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "i":
            tag = "em"
        if tag == "b":
            tag = "strong"
        if tag not in self.KEEP:
            self.stack.append(None)
            return
        keep = {}
        if tag == "a" and "href" in attrs:
            keep["href"] = attrs["href"]
        if tag == "span" and "smallcaps" in (attrs.get("style") or "") + (attrs.get("class") or ""):
            keep["class"] = "sc"
        node = [tag, keep]
        self.stack.append(node)

    def handle_endtag(self, tag):
        node = self.stack.pop()
        if node is None:
            return
        parent = next(n for n in reversed(self.stack) if n is not None)
        if node[0] == "span" and not node[1]:
            for child in node[2:]:  # pandoc's case-protection spans carry nothing
                self.append(parent, child)
        else:
            parent.append(node)

    def append(self, parent, child):
        if isinstance(child, str) and len(parent) > 2 and isinstance(parent[-1], str):
            parent[-1] += child
        else:
            parent.append(child)

    def handle_data(self, data):
        self.append(next(n for n in reversed(self.stack) if n is not None), data)


def xexpr(fragment):
    p = XExpr()
    p.feed(fragment.strip())
    p.close()
    return p.stack[0][2:]


def pandoc_html(md):
    with tempfile.TemporaryDirectory() as tmp:
        bib = pathlib.Path(tmp) / "refs.bib"
        local = LOCAL_BIB.read_text(encoding="utf-8") if LOCAL_BIB.exists() else ""
        bib.write_text(BIB.read_text(encoding="utf-8") + "\n" + local + "\n@misc{zzdummy, title = {Dummy}}\n",
                       encoding="utf-8")
        out = subprocess.run(
            ["pandoc", "--from", "markdown", "--to", "html5", "--citeproc",
             "--bibliography", str(bib), "--csl", str(CSL), "--wrap=none"],
            input=md, capture_output=True, text=True, check=True)
    return out.stdout


def citation(key, loc):
    return f"[@{key}, {loc}]" if loc else f"[@{key}]"


def run_pandoc(found):
    """Full and short notes for every (key, locator) the sources use.

    Each round cites one locator variant of every key, so every citation in a
    round is that work's first (full form); then each again (short form). A
    dummy citation sits between every pair, so no citation ever directly
    repeats the previous one and the style never produces "Ibid." (CITE-3).
    """
    notes = {}
    bib_entries = []
    rounds = max(len(v) for v in found.values())
    for r in range(rounds):
        batch = [(k, locs[r]) for k, locs in found.items() if r < len(locs)]
        cites = []
        for k, loc in batch:
            cites += [citation(k, loc), "[@zzdummy]"]
        for k, loc in batch:
            cites += [citation(k, loc), "[@zzdummy]"]
        md = "---\nnocite: '@*'\n---\n\n" + "\n\n".join(f"Text{c}." for c in cites) + "\n"
        page = pandoc_html(md)
        fns = re.findall(r'<li id="fn(\d+)"[^>]*>\s*<p>(.*?)</p>\s*</li>', page, re.S)
        fns = [re.sub(r'<a href="#fnref\d+"[^>]*>.*?</a>', "", n).strip() for _, n in fns]
        if len(fns) != len(cites):
            sys.exit(f"refs: expected {len(cites)} notes from pandoc, got {len(fns)}")
        n = len(batch)
        for i, (k, loc) in enumerate(batch):
            notes[(k, loc)] = (fns[2 * i], fns[2 * (n + i)])
        if r == 0:
            bib_entries = [(k, e) for k, e in
                           re.findall(r'<div id="ref-([^"]+)" class="csl-entry"[^>]*>(.*?)</div>', page, re.S)
                           if k != "zzdummy"]
    return notes, bib_entries


def field(entry, name):
    for n, v in parse_entry(entry)[2]:
        if n.lower() == name:
            return v.strip("{}\"").strip()
    return None


def plain(tex):
    """A BibTeX value as plain text: braces, escapes and dashes resolved."""
    s = re.sub(r"\\([&%$#_])", r"\1", tex or "")
    s = s.replace("---", "—").replace("--", "–")
    s = re.sub(r"[{}]", "", s).replace("~", "\u00a0")
    return re.sub(r"\s+", " ", s).strip()


TYPES = {"book": "Book", "article": "Article", "incollection": "Chapter", "inbook": "Chapter",
         "inproceedings": "Paper", "thesis": "Thesis", "phdthesis": "Thesis", "mastersthesis": "Thesis",
         "report": "Report", "techreport": "Report", "online": "Web page", "misc": "Other",
         "collection": "Book", "unpublished": "Manuscript"}


def facts(entry):
    """What /bibliography shows and sorts by (BIB-4): the title, the authors'
    (or editors') family names, the year and the type of work."""
    kind = parse_entry(entry)[0].lower()
    people = field(entry, "author") or field(entry, "editor") or ""
    families = [plain(p.split(",")[0]) if "," in p else plain(p).split(" ")[-1]
                for p in re.split(r"\s+and\s+", people) if p.strip()]
    year = field(entry, "year") or (field(entry, "date") or "")[:4]
    return {"title": plain(field(entry, "title")), "authors": families,
            "year": plain(year), "type": TYPES.get(kind, kind.capitalize())}


def main():
    found, public = cited()
    if not found:
        BIB.write_text("% Generated by `make refresh`; no citations yet.\n", encoding="utf-8")
        CACHE.write_text("{}\n", encoding="utf-8")
        for f in (LOCAL_BIB, LOCAL_CACHE):
            if f.exists():
                f.unlink()
        print("refs: no citations")
        return
    public_keys = [k for k in found if any((k, loc) in public for loc in found[k])]
    local_keys = [k for k in found if k not in public_keys]
    sources = write_bib(public_keys, local_keys)
    refresh_covers(sources, public_keys, local_keys)
    notes, bib_entries = run_pandoc(found)
    raw = split_entries(BIB.read_text(encoding="utf-8"))
    if LOCAL_BIB.exists():
        raw.update(split_entries(LOCAL_BIB.read_text(encoding="utf-8")))
    order = {k: i for i, (k, _) in enumerate(bib_entries)}
    entries = dict(bib_entries)

    def record(k, locs):
        doi = field(raw[k], "doi")
        return {
            "full": {loc: xexpr(notes[(k, loc)][0]) for loc in locs},
            "short": {loc: xexpr(notes[(k, loc)][1]) for loc in locs},
            "bib": xexpr(entries[k]),
            "order": order[k],
            "doi": doi,
            "url": f"https://doi.org/{doi}" if doi else field(raw[k], "url"),
            **facts(raw[k]),
        }

    # committed: only the forms published pages use; the rest stay local
    cache, local = {}, {}
    for k in found:
        pub_locs = [loc for loc in found[k] if (k, loc) in public]
        draft_locs = [loc for loc in found[k] if (k, loc) not in public]
        if pub_locs:
            cache[k] = record(k, pub_locs)
        if draft_locs:
            local[k] = record(k, draft_locs)
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"refs: {len(cache)} works, {sum(len(v['full']) for v in cache.values())} forms in data/cite-cache.json")
    if local:
        LOCAL_CACHE.write_text(json.dumps(local, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"refs: {sum(len(v['full']) for v in local.values())} forms cited only by drafts, "
              "in data/cite-cache.local.json (not committed)")
    elif LOCAL_CACHE.exists():
        LOCAL_CACHE.unlink()


if __name__ == "__main__":
    main()
