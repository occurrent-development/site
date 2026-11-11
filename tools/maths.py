#!/usr/bin/env python3
"""Render the site's mathematics (MATH-1). Part of `make refresh`.

1. Collect every ◊m{…} in the sources, with whether it is set inline or on
   its own line (◊m[#:display #t]{…}), and where it stands (file and line).
2. For each distinct TeX source not yet in the cache, typeset one small
   document with LuaLaTeX, unicode-math and Libertinus Math, and convert it
   with dvisvgm to an SVG whose glyphs are plain paths: no <use>, no <defs>,
   no ids, so the same expression can stand twice on one page (an aside and
   its popup) without any id colliding.
3. Write data/math-cache.json, keyed by the SHA-256 of the source, and drop
   entries no source uses any more. Expressions used only by drafts go to
   data/math-cache.local.json, which is not committed (as CITE-5a keeps a
   draft's citations local).

`make` never runs this and never needs TeX (BUILD-2): the build inlines the
cached SVG, and a source missing from the cache fails the build with a
message to run `make refresh` (as CITE-9 does).

The cache's shape, per source:

  "<sha256 of the source>": {
    "tex": "W_a^{\\min}",
    "inline":  {"v": 1, "viewBox": "x y w h", "width": 2.21, "height": 1.11,
                "depth": 0.218, "body": [["path", {"d": "M…"}], …]},
    "display": { … the same, set in \\displaystyle … }
  }

width, height and depth are in em of the surrounding text (the document is
set at 10pt, so 1em = 10pt); depth is how far the drawing reaches below the
baseline, so `vertical-align: -<depth>em` sets the expression on the line.
`body` is the SVG's content as X-expressions, as refs.py stores notes.
Only the forms the sources use are rendered.

Errors are reported as `file:line:col: message` so that Emacs's compilation
mode (od-render-math) can take you to the expression.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "math-cache.json"
LOCAL_CACHE = ROOT / "data" / "math-cache.local.json"
SKIP_DIRS = {"public", "compiled", ".git", "node_modules", "support"}   # BUILD-3a
DRAFT = re.compile(r"◊define-meta\[status\]\{\s*draft\s*\}")

# Bump when the rendering changes, so that `make refresh` renders again.
VERSION = 2
# The document's size: 10pt, so a length in pt / 10 is a length in em.
SIZE_PT = 10
BP_PER_PT = 72 / 72.27          # dvisvgm's user unit is the big point
EM_BP = SIZE_PT * BP_PER_PT

PREAMBLE = r"""\documentclass[10pt]{article}
\usepackage{amsmath}
\usepackage{fontspec}
\usepackage{unicode-math}
\setmainfont{LibertinusSerif}[Extension=.otf, UprightFont=*-Regular, ItalicFont=*-Italic,
  BoldFont=*-Bold, BoldItalicFont=*-BoldItalic]
\setmathfont{LibertinusMath-Regular.otf}
\usepackage[active,tightpage,lyx]{preview}
\setlength\PreviewBorder{0pt}
\pagestyle{empty}
\begin{document}
"""

WS = re.compile(r"[ \t\r\n]+")


def normalise(tex):
    """The source as the build sees it: runs of white space are one space,
    none at either end. pollen.rkt's ◊m does exactly the same."""
    return WS.sub(" ", tex).strip()


def digest(tex):
    return hashlib.sha256(tex.encode("utf-8")).hexdigest()


# ── Finding ◊m in the sources ───────────────────────────────────────────────

M_TAG = re.compile(r"◊(m|formula)(?=[\[{|])")   # ◊formula is always display (FORMULA-1)
DISPLAY = re.compile(r"#:display\s+#t\b")


def blank_comments(text):
    """◊; comments to the end of the line become spaces, so a commented-out
    expression is not rendered and line numbers stay right."""
    return re.sub(r"◊;[^\n]*", lambda m: " " * len(m.group(0)), text)


def balanced(text, i):
    """text[i] is "{"; return the index just past its matching "}", or -1."""
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j + 1
    return -1


def scan(text):
    """Yield (offset, display?, tex) for every ◊m in TEXT."""
    text = blank_comments(text)
    for m in M_TAG.finditer(text):
        i = m.end()
        display = m.group(1) == "formula"
        if text.startswith("[", i):
            close = text.find("]", i)
            if close < 0:
                continue
            display = display or bool(DISPLAY.search(text[i:close]))
            i = close + 1
        if text.startswith("|{", i):              # ◊m|{ … }|: braces need not balance
            close = text.find("}|", i + 2)
            if close < 0:
                continue
            body = text[i + 2:close]
        elif text.startswith("{", i):
            end = balanced(text, i)
            if end < 0:
                continue
            body = text[i + 1:end - 1]
        else:
            continue
        yield m.start(), display, body


def position(text, offset):
    line = text.count("\n", 0, offset) + 1
    col = offset - (text.rfind("\n", 0, offset) + 1) + 1
    return line, col


def sources():
    """{tex: {"forms": set, "public": bool, "where": [(path, line, col)]}}."""
    found = {}
    for path in sorted(ROOT.glob("**/*.pm")):
        rel = path.relative_to(ROOT)
        if SKIP_DIRS & set(rel.parts):
            continue
        if path.name.startswith(".#") or not path.is_file():   # Emacs lock files
            continue
        text = path.read_text(encoding="utf-8")
        draft = bool(DRAFT.search(text))
        for offset, display, body in scan(text):
            tex = normalise(body)
            if not tex:
                continue                                  # the build's error (MATH-1)
            rec = found.setdefault(tex, {"forms": set(), "public": False, "where": []})
            rec["forms"].add("display" if display else "inline")
            rec["public"] |= not draft
            rec["where"].append((str(rel),) + position(text, offset))
    return found


# ── Rendering ───────────────────────────────────────────────────────────────

class TexError(Exception):
    pass


def tex_error(log):
    """The first TeX error in LOG, as one line."""
    lines = log.splitlines()
    for k, line in enumerate(lines):
        if line.startswith("! "):
            msg = line[2:].strip()
            for more in lines[k + 1:k + 8]:
                if more.startswith("l."):
                    context = more.split(" ", 1)[1].strip() if " " in more else ""
                    if context:
                        msg += f" (at {context})"
                    break
            return msg
    for line in lines:
        if "error" in line.lower():
            return line.strip()
    return "LuaLaTeX failed; see its log"


SNIPPET = re.compile(r"Preview: Snippet \d+ (-?\d+) (-?\d+) (-?\d+)")


def strip_ns(tag):
    return tag.split("}", 1)[1] if tag.startswith("{") else tag


def xexpr(el):
    """An SVG element as an X-expression, without ids or namespaces."""
    attrs = {strip_ns(k): v for k, v in el.attrib.items() if strip_ns(k) != "id"}
    kids = [xexpr(c) for c in el]
    return [strip_ns(el.tag), attrs] + kids


PATH_TOKEN = re.compile(r"[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?")


def fmt(v):
    """A coordinate as short as it can be: 2 decimals, no leading 0, no -0."""
    t = f"{v:.2f}".rstrip("0").rstrip(".")
    if t in ("-0", ""):
        t = "0"
    return t.replace("0.", ".", 1) if t.startswith("0.") else t.replace("-0.", "-.", 1)


def at_origin(d):
    """Move a glyph's path to start at 0,0 and return (d, x, y), the offset.

    dvisvgm writes absolute coordinates, so the same letter twice is two
    different strings; at its own origin, with the offset in a transform,
    it is the same string each time and compresses to almost nothing. Only
    absolute commands occur (dvisvgm without --relative); anything else is
    returned unchanged.
    """
    toks = PATH_TOKEN.findall(d)
    if not toks or toks[0] != "M" or any(t.isalpha() and t not in "MLHVCSQTZ" for t in toks):
        return d, 0.0, 0.0
    x0, y0 = float(toks[1]), float(toks[2])
    out, cmd, i, pair = [], None, 0, 0
    while i < len(toks):
        t = toks[i]
        if t.isalpha():
            cmd, pair = t, 0
            out.append(t)
            i += 1
            continue
        v = float(t)
        if cmd == "H":
            v -= x0
        elif cmd == "V":
            v -= y0
        else:
            v -= x0 if pair % 2 == 0 else y0
            pair += 1
        out.append(fmt(v))
        i += 1
    # numbers are separated by a space unless the next one starts with "-"
    d2 = ""
    for t in out:
        if d2 and not t.isalpha() and not d2[-1].isalpha() and not t.startswith("-"):
            d2 += " "
        d2 += t
    return d2, x0, y0


def compact(el):
    """Each glyph's path at its own origin, offset by a transform (see at_origin)."""
    if el[0] == "path" and "d" in el[1] and "transform" not in el[1]:
        d, x, y = at_origin(el[1]["d"])
        if (x, y) != (0.0, 0.0):
            el[1] = {**el[1], "d": d, "transform": f"translate({fmt(x)} {fmt(y)})"}
    return [el[0], el[1]] + [compact(c) for c in el[2:]]


def render(tex, form, workdir):
    """Typeset TEX in FORM ("inline" or "display"); return the cache record."""
    style = r"\displaystyle " if form == "display" else ""
    doc = PREAMBLE + r"\begin{preview}$" + style + tex + "$\\end{preview}\n\\end{document}\n"
    d = pathlib.Path(tempfile.mkdtemp(dir=workdir))
    (d / "m.tex").write_text(doc, encoding="utf-8")
    run = subprocess.run(["lualatex", "-interaction=nonstopmode", "-halt-on-error",
                          "-no-shell-escape", "-output-format=dvi", "m.tex"],
                         cwd=d, capture_output=True, text=True, errors="replace")
    log = (d / "m.log").read_text(encoding="utf-8", errors="replace") if (d / "m.log").exists() else run.stdout
    if run.returncode != 0 or not (d / "m.dvi").exists():
        raise TexError(tex_error(log))
    m = SNIPPET.search(log)
    if not m:
        raise TexError("no preview box in the log (is the preview package installed?)")
    wd_bp = int(m.group(3)) / 65536 * BP_PER_PT
    # Absolute coordinates: dvisvgm 3.2.2's --relative writes some absolute
    # values under relative commands (seen 2026-11-10: glyphs drawn as spikes).
    conv = subprocess.run(["dvisvgm", "--no-fonts=1", "--exact-bbox", "--precision=4",
                           "--optimize", "--stdout", "m.dvi"],
                          cwd=d, capture_output=True)
    if conv.returncode != 0:
        raise TexError("dvisvgm failed: " + conv.stderr.decode("utf-8", "replace").strip()[-300:])
    svg = ET.fromstring(conv.stdout)
    x, y, w, h = (float(v) for v in svg.attrib["viewBox"].split())
    # dvisvgm's viewBox is the ink; the baseline is y = 0 and the box starts
    # at x = 0, so keep TeX's own width (its spacing) as well as the ink.
    x0, x1 = min(x, 0.0), max(x + w, wd_bp)
    y0, y1 = y, y + h
    body = []
    for child in svg:
        tag = strip_ns(child.tag)
        if tag in ("defs", "style", "title", "desc"):
            if len(child):
                raise TexError(f"dvisvgm wrote <{tag}> content; the cache cannot hold it without ids")
            continue
        if tag == "g" and not [k for k in child.attrib if strip_ns(k) != "id"]:
            body.extend(xexpr(c) for c in child)      # the page group: lift its contents
        else:
            body.append(xexpr(child))
    body = [compact(b) for b in body]
    if any("href" in json.dumps(b) for b in body):
        raise TexError("the SVG refers to an id (<use>); it would collide on a page")
    shutil.rmtree(d, ignore_errors=True)
    r = lambda v: round(v, 3)
    return {
        "v": VERSION,
        "viewBox": f"{r(x0)} {r(y0)} {r(x1 - x0)} {r(y1 - y0)}",
        "width": round((x1 - x0) / EM_BP, 4),
        "height": round((y1 - y0) / EM_BP, 4),
        "depth": round(y1 / EM_BP, 4),
        "body": body,
    }


def check_tools():
    missing = [t for t in ("lualatex", "dvisvgm", "kpsewhich") if not shutil.which(t)]
    if missing:
        sys.exit("math: not found: " + ", ".join(missing) +
                 ". Install TeX Live (MacTeX) with unicode-math, preview, libertinus-fonts and dvisvgm.")
    for f in ("unicode-math.sty", "preview.sty", "LibertinusMath-Regular.otf", "LibertinusSerif-Regular.otf"):
        if not subprocess.run(["kpsewhich", f], capture_output=True, text=True).stdout.strip():
            sys.exit(f"math: TeX cannot find {f}; install it with tlmgr (MATH-1)")


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--force", action="store_true", help="render every expression again")
    args = ap.parse_args()

    found = sources()
    old = {**load(LOCAL_CACHE), **load(CACHE)}
    jobs = []
    for tex, rec in found.items():
        entry = old.get(digest(tex))
        for form in sorted(rec["forms"]):
            have = entry and entry.get("tex") == tex and entry.get(form)
            if args.force or not have or have.get("v") != VERSION:
                jobs.append((tex, form))

    errors = []
    rendered = {}
    if jobs:
        check_tools()
        with tempfile.TemporaryDirectory(prefix="od-math-") as work, \
                concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
            futures = {pool.submit(render, tex, form, work): (tex, form) for tex, form in jobs}
            for fut in concurrent.futures.as_completed(futures):
                tex, form = futures[fut]
                try:
                    rendered[(tex, form)] = fut.result()
                except TexError as e:
                    for path, line, col in found[tex]["where"]:
                        errors.append(f"{path}:{line}:{col}: TeX error in ◊m{{{tex}}} ({form}): {e}")

    cache, local = {}, {}
    for tex, rec in sorted(found.items()):
        h = digest(tex)
        entry = {"tex": tex}
        prev = old.get(h) if old.get(h, {}).get("tex") == tex else {}
        for form in sorted(rec["forms"]):
            got = rendered.get((tex, form)) or (prev or {}).get(form)
            if got:
                entry[form] = got
        if len(entry) > 1:
            (cache if rec["public"] else local)[h] = entry

    dropped = len(set(old) - set(cache) - set(local))
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    if local:
        LOCAL_CACHE.write_text(json.dumps(local, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                               encoding="utf-8")
    elif LOCAL_CACHE.exists():
        LOCAL_CACHE.unlink()
    print(f"math: {len(found)} expressions, {len(rendered)} rendered, {dropped} no longer used and dropped"
          + (f", {len(local)} only in drafts (data/math-cache.local.json, not committed)" if local else ""))
    for e in sorted(errors):
        print(e, file=sys.stderr)
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
