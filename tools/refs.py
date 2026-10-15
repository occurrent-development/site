#!/usr/bin/env python3
"""Refresh the citation caches (BUILD-3, CITE-5). Part of `make refresh`.

1. Collect every key cited in the sources (◊cite["key"]).
2. Write refs/refs.bib with just those entries, taken from the Zotero
   (Better BibTeX) export named by $ZOTERO_BIB, else kept from the existing
   refs.bib. Private fields (abstracts, notes, file paths, keywords) are
   dropped: the repository is public.
3. Run pandoc --citeproc with the Chicago notes style and write, per key,
   the full note, the short note and the bibliography entry, plus DOI/URL
   and bibliography order, to data/cite-cache.json.

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
CITE = re.compile(r'◊cite\[\s*"([^"]+)"([^\]]*)\]', re.S)
LOC = re.compile(r'#:loc\s+"([^"]*)"')


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
        for key, rest in CITE.findall(text):
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
    write_bib(public_keys, local_keys)
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
