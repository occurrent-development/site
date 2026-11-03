"""Tests for the covers step of `make refresh` (BIB-7), and the bibliography's
facts (BIB-4). Run by `make test`: python3 -m unittest discover -s tools -p '*_test.py'.

The fixture .bib (tests/refs/fixture.bib) has `file` fields pointing at a
100 × 150 px cover in tests/refs/; Better BibTeX writes absolute paths, so
the test fills them in.
"""

import pathlib
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import refs  # noqa: E402

FIXTURES = refs.ROOT / "tests" / "refs"


def fixture_entries():
    text = (FIXTURES / "fixture.bib").read_text(encoding="utf-8").replace("@FIXTURES@", str(FIXTURES))
    return refs.split_entries(text)


class Stubs(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.saved = refs.REFERENCES
        refs.REFERENCES = pathlib.Path(self.tmp.name) / "references"
        self.addCleanup(lambda: setattr(refs, "REFERENCES", self.saved))

    def test_an_empty_commentary_for_each_new_public_key(self):
        made = refs.ensure_commentary_stubs(["aWork2001", "another2002"])
        self.assertEqual(made, ["aWork2001", "another2002"])
        text = (refs.REFERENCES / "aWork2001.pm").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("#lang pollen"))
        self.assertNotIn("\n\n\n", text)

    def test_the_stub_is_the_one_emacs_makes(self):
        el = (refs.ROOT / "emacs" / "occurrent.el").read_text(encoding="utf-8")
        for line in refs.STUB.strip().splitlines():
            self.assertIn(line, el)

    def test_never_overwrites_a_commentary(self):
        refs.REFERENCES.mkdir()
        mine = refs.REFERENCES / "aWork2001.pm"
        mine.write_text("#lang pollen\n\nMy view.\n", encoding="utf-8")
        self.assertEqual(refs.ensure_commentary_stubs(["aWork2001"]), [])
        self.assertIn("My view.", mine.read_text(encoding="utf-8"))


class Covers(unittest.TestCase):
    def setUp(self):
        self.entries = fixture_entries()
        self.tmp = tempfile.TemporaryDirectory()
        self.out = pathlib.Path(self.tmp.name)
        self.saved = (refs.COVERS, refs.LOCAL_COVERS)
        refs.COVERS, refs.LOCAL_COVERS = self.out / "covers", self.out / "covers.local"

    def tearDown(self):
        refs.COVERS, refs.LOCAL_COVERS = self.saved
        self.tmp.cleanup()

    def test_copies_and_sizes_the_cover(self):
        from PIL import Image
        refs.refresh_covers(self.entries, ["withCover2001"], [])
        copy = refs.COVERS / "withCover2001.jpg"
        self.assertTrue(copy.exists())
        with Image.open(copy) as img:
            self.assertEqual(img.format, "JPEG")
            self.assertEqual(img.size, (100, 150))   # never enlarged; the longest side stops at 1600

    def test_downsizes_to_1600(self):
        from PIL import Image
        big = self.out / "cover.jpg"
        Image.new("RGB", (2400, 3200), (10, 20, 30)).save(big)
        dest = self.out / "small.jpg"
        refs.write_cover(big, dest)
        with Image.open(dest) as img:
            self.assertEqual(img.size, (1200, 1600))

    def test_no_image_attachment_no_cover_no_error(self):
        refs.refresh_covers(self.entries, ["noImage2002"], [])
        self.assertEqual(list(refs.COVERS.glob("*.jpg")) if refs.COVERS.exists() else [], [])

    def test_two_images_without_a_cover_is_an_error_naming_them(self):
        with self.assertRaises(SystemExit) as e:
            refs.cover_source("twoImages2003", self.entries["twoImages2003"])
        self.assertIn("front.jpg", str(e.exception))
        self.assertIn("other.png", str(e.exception))

    def test_heic_asks_for_a_jpeg(self):
        with self.assertRaises(SystemExit) as e:
            refs.cover_source("heic2004", self.entries["heic2004"])
        self.assertIn("JPEG", str(e.exception))

    def test_a_cover_gone_from_zotero_is_deleted(self):
        refs.refresh_covers(self.entries, ["withCover2001"], [])
        # the work is still cited, but its entry no longer has the attachment
        entries = dict(self.entries, withCover2001=self.entries["noImage2002"].replace("noImage2002", "withCover2001"))
        refs.refresh_covers(entries, ["withCover2001"], [])
        self.assertFalse((refs.COVERS / "withCover2001.jpg").exists())

    def test_drafts_covers_stay_local(self):
        refs.refresh_covers(self.entries, [], ["withCover2001"])
        self.assertTrue((refs.LOCAL_COVERS / "withCover2001.jpg").exists())
        self.assertFalse((refs.COVERS / "withCover2001.jpg").exists())

    def test_file_field_still_stripped(self):
        self.assertNotIn("file", refs.strip_private(self.entries["withCover2001"]))


# pandoc is a dependency of `make refresh` only (BUILD-2); CI's `make` has none
@unittest.skipUnless(shutil.which("pandoc"), "pandoc is needed only by `make refresh`")
class Facts(unittest.TestCase):
    """BIB-10: one parse, pandoc's CSL record, with the titles as stored."""

    def setUp(self):
        self.csl = refs.csl_records(fixture_entries())

    def test_facts_from_the_csl_record(self):
        self.assertEqual(refs.facts(self.csl["withCover2001"]),
                         {"title": "A Book with a Cover", "authors": ["Author"], "year": "2001", "type": "Book"})
        self.assertEqual(refs.facts(self.csl["noImage2002"])["authors"], ["Writer", "Other"])
        self.assertEqual(refs.facts(self.csl["aChapter2005"])["type"], "Chapter")

    def test_titles_keep_their_case(self):
        # pandoc would sentence-case these
        self.assertEqual(self.csl["withCover2001"]["title"], "A Book with a Cover")
        self.assertEqual(self.csl["aChapter2005"]["container-title"], "The Collected Book")

    def test_the_racket_fixture_is_this_record(self):
        # tests/refs/fixture-csl.json feeds the RackUnit test of the BIB-10 fields
        import json
        fixture = json.loads((FIXTURES / "fixture-csl.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture, self.csl)

    def test_quotations_are_citations(self):
        text = '◊cite["a" #:loc "p. 3"]{x} ◊cite["b" #:block #t #:loc "p. 9"]{y} ◊cite["c"]'
        self.assertEqual([(k, (refs.LOC.search(r) or [None, ""])[1]) for k, r in refs.CITE.findall(text)],
                         [("a", "p. 3"), ("b", "p. 9"), ("c", "")])


if __name__ == "__main__":
    unittest.main()
