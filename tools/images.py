#!/usr/bin/env python3
"""Build the image variants for every ◊figure (IMG-1).

For each raster source: AVIF (avifenc), WebP and a JPEG or PNG fallback
(Pillow) at several widths no larger than the source. Variants go to
assets/img/ with content-hashed names and are not committed; the manifest
assets/img/images.json gives the template their URLs and the source's
intrinsic size. SVG sources are inlined by the build, so only their size is
recorded. Runs offline (BUILD-2) and only re-encodes what changed.

Run from the repository root: python3 tools/images.py
"""

import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "img"
MANIFEST = OUT / "images.json"
SKIP_DIRS = {"public", "compiled", ".git", "node_modules"}
WIDTHS = [480, 800, 1200, 1600, 2400]
WARN_BYTES = 2 * 1024 * 1024
FIGURE = re.compile(r'◊figure\[\s*"([^"]+)"')


def sources():
    found = {}
    for pm in sorted(ROOT.glob("**/*.pm")):
        if SKIP_DIRS & set(pm.relative_to(ROOT).parts):
            continue
        for src in FIGURE.findall(pm.read_text(encoding="utf-8")):
            path = (pm.parent / src).resolve()
            if not path.exists():
                sys.exit(f"images: {pm.relative_to(ROOT)}: no file {src}")
            found[path.relative_to(ROOT).as_posix()] = path
    return found


def svg_size(path):
    text = path.read_text(encoding="utf-8")
    m = re.search(r'viewBox="\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)', text)
    if not m:
        sys.exit(f"images: {path.relative_to(ROOT)} needs a viewBox")
    return round(float(m.group(1))), round(float(m.group(2)))


def variants(key, path, digest):
    img = Image.open(path)
    img.load()
    w, h = img.size
    alpha = img.mode in ("RGBA", "LA") or "transparency" in img.info
    fallback = "png" if alpha else "jpg"
    widths = sorted({x for x in WIDTHS if x < w} | {min(w, WIDTHS[-1])})
    stem = path.stem
    out = {"width": w, "height": h, "fallback": fallback, "sources": {"avif": [], "webp": [], fallback: []}}
    for width in widths:
        height = round(h * width / w)
        resized = img if width == w else img.resize((width, height), Image.LANCZOS)
        mode = "RGBA" if alpha else "RGB"
        resized = resized.convert(mode)
        for fmt in ("avif", "webp", fallback):
            name = f"{stem}.{digest}-{width}.{fmt}"
            target = OUT / name
            if not target.exists():
                if fmt == "webp":
                    resized.save(target, "WEBP", quality=80, method=6)
                elif fmt == "jpg":
                    resized.save(target, "JPEG", quality=82, optimize=True, progressive=True)
                elif fmt == "png":
                    resized.save(target, "PNG", optimize=True)
                else:
                    with tempfile.TemporaryDirectory() as tmp:
                        png = pathlib.Path(tmp) / "in.png"
                        resized.save(png, "PNG")
                        subprocess.run(["avifenc", "-q", "60", "-s", "6", str(png), str(target)],
                                       check=True, capture_output=True)
            out["sources"][fmt].append({"url": f"/assets/img/{name}", "w": width})
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    keep = {MANIFEST.name}
    for key, path in sources().items():
        if path.stat().st_size > WARN_BYTES:
            print(f"images: warning: {key} is over 2 MB")
        if path.suffix.lower() == ".svg":
            w, h = svg_size(path)
            manifest[key] = {"svg": True, "width": w, "height": h}
            continue
        digest = hashlib.sha256(path.read_bytes() + repr(WIDTHS).encode()).hexdigest()[:10]
        entry = variants(key, path, digest)
        manifest[key] = entry
        for urls in entry["sources"].values():
            keep |= {pathlib.Path(u["url"]).name for u in urls}
        print(f"images: {key} {entry['width']}×{entry['height']}, "
              f"{len(entry['sources']['avif'])} widths")
    for stale in OUT.iterdir():
        if stale.name not in keep:
            stale.unlink() if stale.is_file() else shutil.rmtree(stale)
    MANIFEST.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
