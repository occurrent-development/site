#!/usr/bin/env python3
"""Browser tests for the interactive layer (Phase 2c), in headless Chrome.

    python3 tools/browser_test.py            run the tests against public/
    python3 tools/browser_test.py --shots D  also save the specimen screenshots to D
    python3 tools/browser_test.py --browser firefox|safari
                                             run the tests in another browser (by hand;
                                             Safari opens a window and needs no driver)

Serves public/ as the Worker does (/name -> name.html) with the harness in
tests/browser/ at /__test/, loads the harness in headless Chrome and reads
the results it writes into the page. The harness drives /specimen in a
same-origin frame: the contents heading swapping to the title when stuck
(TOC-2), Esc closing only the focused popup and the cap of six pinned
(POP-9), the scratch pad surviving a reload (POP-12), and the rest listed in
tests/browser/harness.js.

Headless Chrome dumps or captures a page when it has loaded, so the harness
holds its own load event open with a request to /__wait, which the server
answers only once the harness has posted its results to /__results.

No third-party Python is needed. Without Chrome the tests are skipped with a
message, not failed, so `make` still builds on a machine without it; CI's
runners have Chrome.
"""

import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = os.path.join(ROOT, "public")
HARNESS = os.path.join(ROOT, "tests", "browser")

CHROMES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
]

# The screenshots the report asks for (HANDOVER-PHASE2C §7), as harness
# scenarios: name, window width and height, scenario, theme.
SHOTS = [
    ("xl-2560-top", 2560, 1440, "top", "light"),
    ("xl-2560-stuck", 2560, 1440, "stuck", "light"),
    ("xl-2560-bar", 2560, 1440, "bar", "light"),
    ("xl-2560-pins", 2560, 1440, "pins", "light"),
    ("xl-2560-pad", 2560, 1440, "pad", "light"),
    ("xl-2560-pins", 2560, 1440, "pins", "dark"),
    ("xl-1680", 1680, 1050, "stuck", "light"),
    ("l-1400-contents", 1400, 900, "toc", "light"),
    ("l-1400", 1400, 900, "pins", "light"),
    ("m-900", 900, 900, "def", "light"),
    ("s-390", 390, 844, "def", "dark"),
]


def chrome():
    for c in CHROMES:
        p = c if os.path.isabs(c) else shutil.which(c)
        if p and os.path.exists(p):
            return p
    return None


DONE = threading.Event()
RESULTS = {}


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/__wait"):
            DONE.wait(150)
            self.send_response(204)
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        if self.path.startswith("/__results"):
            n = int(self.headers.get("Content-Length", 0))
            RESULTS["body"] = self.rfile.read(n).decode()
            self.send_response(204)
            self.end_headers()
            DONE.set()
            return
        self.send_error(404)

    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        if path.startswith("/__test/"):
            return os.path.join(HARNESS, path[len("/__test/"):])
        p = os.path.join(PUBLIC, path.lstrip("/"))
        if os.path.isdir(p):
            p = os.path.join(p, "index.html")
        if not os.path.exists(p) and os.path.exists(p + ".html"):
            p += ".html"
        return p

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


def serve():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, f"http://127.0.0.1:{srv.server_address[1]}"


# A runner with no mouse makes headless Chrome report `(hover: none)`, and
# the page then takes the touch path (popins, no pinning: POP-5, POP-9), as
# GitHub's Linux runners did on 2026-10-26. The tests are for a pointer
# device, so the browser is told it has one: hover = 2 (hover),
# pointer = 4 (fine), Blink's own values.
POINTER = "--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"


def run_chrome(binary, profile, args, url, timeout=180):
    cmd = [binary, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
           "--no-default-browser-check", "--disable-extensions", f"--user-data-dir={profile}",
           POINTER, *args, url]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


FIREFOX = "/Applications/Firefox.app/Contents/MacOS/firefox"


def other_browser(name, base):
    """Run the tests in Firefox (headless) or Safari (a window), returning the
    results the harness posts, or None."""
    DONE.clear()
    RESULTS.clear()
    url = f"{base}/__test/harness.html?run=tests"
    if name == "firefox":
        exe = FIREFOX if os.path.exists(FIREFOX) else shutil.which("firefox")
        if not exe:
            return None
        profile = tempfile.mkdtemp(prefix="od-browser-test-ff-")
        try:
            subprocess.run([exe, "--headless", "--no-remote", "--profile", profile, "--window-size=2600,1500",
                            "--screenshot", os.path.join(profile, "shot.png"), url],
                           capture_output=True, text=True, timeout=180)
        finally:
            shutil.rmtree(profile, ignore_errors=True)
    elif name == "safari":
        subprocess.run(["open", "-g", "-a", "Safari", url])
        DONE.wait(150)
    return json.loads(RESULTS["body"]) if "body" in RESULTS else None


def report(results, where):
    failed = [t for t in results if not t["ok"]]
    for t in results:
        print(f"  {'ok  ' if t['ok'] else 'FAIL'} {t['name']}" + ("" if t["ok"] else f": {t['detail']}"))
    print(f"browser tests: {len(results) - len(failed)} of {len(results)} passed ({where})")
    return failed


def main():
    if "--browser" in sys.argv and sys.argv[sys.argv.index("--browser") + 1] != "chrome":
        name = sys.argv[sys.argv.index("--browser") + 1]
        srv, base = serve()
        try:
            results = other_browser(name, base)
        finally:
            srv.shutdown()
        if results is None:
            print(f"browser tests: no results from {name}")
            return 1
        return 1 if report(results, name) else 0
    shots = None
    if "--shots" in sys.argv:
        shots = os.path.abspath(sys.argv[sys.argv.index("--shots") + 1])
        os.makedirs(shots, exist_ok=True)
    binary = chrome()
    if not binary:
        print("browser tests: skipped, no Chrome found (they run in CI)")
        return 0
    if not os.path.exists(os.path.join(PUBLIC, "specimen.html")):
        print("browser tests: public/ is not built; run make first")
        return 1
    srv, base = serve()
    profile = tempfile.mkdtemp(prefix="od-browser-test-")
    try:
        DONE.clear()
        RESULTS.clear()
        r = run_chrome(binary, profile, ["--window-size=2600,1500", "--dump-dom"],
                       f"{base}/__test/harness.html?run=tests")
        if "body" not in RESULTS:
            print("browser tests: the harness posted no results")
            print(r.stdout[-2000:], r.stderr[-2000:])
            return 1
        results = json.loads(RESULTS["body"])
        failed = report(results, "headless Chrome")
        if shots:
            for name, w, h, scenario, theme in SHOTS:
                out = os.path.join(shots, f"{name}-{theme}.png" if theme == "dark" else f"{name}.png")
                DONE.clear()
                # headless Chrome keeps a window at least ~500 px wide, so the
                # frame takes the width and the shot is cropped to it
                run_chrome(binary, profile, [f"--window-size={max(w, 600)},{h}", f"--screenshot={out}"],
                           f"{base}/__test/harness.html?show={scenario}&theme={theme}&w={w}&h={h}")
                if w < 600:
                    try:
                        from PIL import Image
                        Image.open(out).crop((0, 0, w, h)).save(out)
                    except ImportError:
                        pass
                print(f"  shot {out}")
        return 1 if failed else 0
    finally:
        srv.shutdown()
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
