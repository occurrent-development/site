"""Tests for tools/maths.py (MATH-1). Run by `make test`.

The rendering test needs TeX and is skipped without it, so `make test`
stays TeX-free (BUILD-2); everything else reads the committed cache.
"""

import json
import pathlib
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import maths  # noqa: E402


class Scan(unittest.TestCase):
    def found(self, text):
        return [(d, maths.normalise(b)) for _, d, b in maths.scan(text)]

    def test_nested_braces_display_and_the_bars(self):
        text = ("A ◊m{W_a^{\\min}} and ◊m{\\frac{a}{b}}.\n"
                "◊m[#:display #t]{\n\\bar{x} = 1\n}\n"
                "◊m|{\\left\\{ x \\right.}| ◊margin{not maths} ◊m[#:display #f]{y}")
        self.assertEqual(self.found(text), [
            (False, "W_a^{\\min}"), (False, "\\frac{a}{b}"), (True, "\\bar{x} = 1"),
            (False, "\\left\\{ x \\right."), (False, "y")])

    def test_comments_are_skipped_and_positions_kept(self):
        text = "◊; ◊m{commented}\nLine two ◊m{x}"
        [(offset, _, body)] = list(maths.scan(text))
        self.assertEqual(body, "x")
        self.assertEqual(maths.position(text, offset), (2, 10))

    def test_normalise_matches_the_build(self):
        # pollen.rkt's math-source: runs of space, tab and newline are one space
        self.assertEqual(maths.normalise("  a\n\t b  "), "a b")


class Cache(unittest.TestCase):
    """The committed cache: keyed by the source's SHA-256, no ids, the fixtures present."""

    @classmethod
    def setUpClass(cls):
        cls.cache = json.loads(maths.CACHE.read_text(encoding="utf-8"))

    def test_shape(self):
        for h, e in self.cache.items():
            self.assertEqual(h, maths.digest(e["tex"]))
            forms = [k for k in e if k != "tex"]
            self.assertTrue(forms and set(forms) <= {"inline", "display"}, forms)
            for f in forms:
                r = e[f]
                self.assertEqual(set(r), {"v", "viewBox", "width", "height", "depth", "body"})
                self.assertEqual(len(r["viewBox"].split()), 4)
                blob = json.dumps(r["body"])
                self.assertNotIn('"id"', blob)
                self.assertNotIn("href", blob)
                self.assertNotIn("url(#", blob)

    def test_fixtures_are_cached_in_both_forms(self):
        for tex in ("W_a^{\\min}", "\\bar{x} = \\frac{1}{n}\\sum_{i=1}^{n} x_i",
                    "\\text{incidence} = \\frac{\\text{new cases}}{\\text{person-time at risk}}"):
            e = self.cache.get(maths.digest(tex))
            self.assertIsNotNone(e, f"{tex} not cached: run `make refresh`")
            self.assertIn("inline", e)
            self.assertIn("display", e)

    def test_ordinary_inline_expression_stays_within_the_line(self):
        # MARK-2: W_a^{\min} reaches no higher than the text's ascenders and no
        # lower than its descenders (Libertinus: about 0.9em and 0.25em)
        r = self.cache[maths.digest("W_a^{\\min}")]["inline"]
        self.assertLess(r["height"] - r["depth"], 0.95)
        self.assertLess(r["depth"], 0.3)


@unittest.skipUnless(shutil.which("lualatex") and shutil.which("dvisvgm"), "TeX is not installed")
class Render(unittest.TestCase):
    def test_render_and_report_errors(self):
        with tempfile.TemporaryDirectory() as work:
            r = maths.render("W_a^{\\min}", "inline", work)
            self.assertGreater(r["depth"], 0.1)            # the subscript goes below the baseline
            self.assertGreater(r["width"], 1.5)
            self.assertNotIn("href", json.dumps(r["body"]))
            d = maths.render("\\sum_{i=1}^{n} x_i", "display", work)
            i = maths.render("\\sum_{i=1}^{n} x_i", "inline", work)
            self.assertGreater(d["height"], i["height"])   # limits above and below
            with self.assertRaises(maths.TexError) as e:
                maths.render("\\notACommand", "inline", work)
            self.assertIn("Undefined control sequence", str(e.exception))


if __name__ == "__main__":
    unittest.main()
