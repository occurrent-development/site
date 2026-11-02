# occurrentdevelopment.com
#
#   make           test, subset fonts, render, assemble public/   (offline; BUILD-2)
#   make test      typography rules (TYPE-14) and the root pass
#   make test-browser  the interactive layer in headless Chrome (skipped without Chrome)
#   make test-emacs  the Emacs mode's tests (needs Emacs 29+)
#   make serve     Pollen project server on http://localhost:8080, drafts' graph merged
#   make refresh   update the committed caches (BUILD-3): refs.bib, cite-cache.json,
#                  covers, invert.json, and Wayback snapshots in link-meta.json
#   make refresh-cites  only refs.bib, cite-cache.json and covers (no network)
#   make clean     remove everything the build generates
#
# Needs: Racket with the pollen package; Python 3 with fonttools, brotli and
# Pillow (tools/requirements.txt); avifenc for figures; pandoc for `make refresh`.

# Machine-specific settings, not committed. Set ZOTERO_BIB there to the Better
# BibTeX auto-export of your Zotero library, e.g.
#   ZOTERO_BIB = ~/Documents/References/Zotero-Library.bib
-include local.mk

RACO    ?= raco
PYTHON  ?= python3
PORT    ?= 8080

FONTS_SRC := $(wildcard assets/fonts/*.otf assets/fonts/*.ttf)
# Emacs's lock files (.#name, a dangling link while a buffer is modified) are not sources.
SOURCES   := $(shell find . -name '*.pm' -not -name '.\#*' -not -path './public/*' -not -path './essays/*/support/*' -not -path './blog/*/support/*') \
             template.html.p pollen.rkt typography.rkt
FONTS     := assets/fonts/fonts.rktd
IMAGES    := assets/img/images.json
IMG_SRC   := $(shell find pages essays blog -path '*/img/*' -type f 2>/dev/null) \
             $(wildcard refs/covers/*.jpg refs/covers.local/*.jpg)

# Files that must never reach public/ (BUILD-3a).
FORBIDDEN := -name '*-Notes.md' -o -name '*.docx' -o -name '*.graffle' -o -name '*.tex'

.PHONY: all test test-browser test-emacs render publish serve refresh refresh-cites clean

all: test publish test-browser

# The root-pass tests read the image manifest for the covers (BIB-7).
test: $(IMAGES)
	$(RACO) test typography-test.rkt pollen-test.rkt
	$(PYTHON) -m unittest discover -s tools -p '*_test.py'
	@! grep -rn --include='*.pm' '◊quote\b' . || \
	  { echo "◊quote is not a tag (Racket's quote swallows it); use ◊blockquote"; exit 1; }

# The interactive layer, in headless Chrome against the built site (TOC-2,
# POP-9…12, TERM-3 and the rest in tests/browser/harness.js). Needs public/.
test-browser:
	$(PYTHON) tools/browser_test.py

# The Emacs mode's tests (TEST-1, TEST-3); not part of `make', so CI needs no Emacs.
# No input: a command that prompts in a test fails instead of waiting.
test-emacs:
	emacs -Q --batch -L emacs -l occurrent-test.el -f ert-run-tests-batch-and-exit < /dev/null

# Subset each face to the characters the site uses (TYPE-8). Writes hashed
# WOFF2 files beside the sources and a manifest the template reads.
$(FONTS): $(FONTS_SRC) $(SOURCES) tools/fonts.py
	$(PYTHON) tools/fonts.py

# Image variants for every figure (IMG-1).
$(IMAGES): $(IMG_SRC) $(SOURCES) tools/images.py
	$(PYTHON) tools/images.py

# The indexes, the home page and the pages built from the link graph
# (glossary, bibliography, changelog) list every post, so they are rebuilt
# whenever anything is.
INDEXES := pages/index.html.pm pages/about.html.pm pages/essays.html.pm pages/blog.html.pm \
           pages/glossary.html.pm pages/bibliography.html.pm pages/changelog.html.pm
# BUILD-4: the link graph is written first, by one walk over every post
# (tools/validate.rkt); every page is then rendered from it. data/links.json
# is in Pollen's cache watchlist, so when the graph changes every page is
# rendered again; `make` is always as good as a full rebuild.
render: $(FONTS) $(IMAGES)
	touch $(INDEXES)
	$(RACO) make tools/validate.rkt && racket tools/validate.rkt --graph && racket tools/validate.rkt
	$(RACO) pollen render -p index.ptree
	$(RACO) pollen render -p build/references/index.ptree

# Pages render beside their sources; public/ gets them flattened to /<name>.
publish: render
	rm -rf public
	mkdir -p public/assets/fonts public/assets/icons public/assets/img public/assets/js public/data
	while read src dest; do mkdir -p "public/$$(dirname "$$dest")"; cp "$$src" "public/$$dest"; done < data/publish.txt
	cp assets/fonts/*.woff2 public/assets/fonts/
	cp assets/icons/*.svg public/assets/icons/
	mkdir -p public/assets/brand && cp assets/brand/* public/assets/brand/
	cp assets/brand/favicon.ico public/favicon.ico
	cp assets/js/site.js assets/js/tables.js public/assets/js/
	find assets/img -type f ! -name images.json -exec cp {} public/assets/img/ \;
	cp data/anchors.json public/data/
	cp -R build/_x public/_x
	cp _headers _redirects public/
	@bad=$$(find public $(FORBIDDEN)); \
	  if [ -n "$$bad" ]; then echo "Refusing to publish: $$bad"; exit 1; fi

# The preview merges the drafts' link graph and citations (lib/graph.rkt):
# OD_PREVIEW=1. Work pages are at /build/references/<key>.html.
serve: $(FONTS) $(IMAGES)
	touch $(INDEXES)
	$(RACO) make tools/validate.rkt && OD_PREVIEW=1 racket tools/validate.rkt --graph
	OD_PREVIEW=1 $(RACO) pollen start . $(PORT)

refresh: refresh-cites
	$(PYTHON) tools/invert.py
	$(PYTHON) tools/wayback.py

# The citation caches alone (CITE-5): pandoc and local files, no network.
# `od-preview` runs this when a page cites a work at a locator not yet cached.
refresh-cites:
	ZOTERO_BIB="$(ZOTERO_BIB)" $(PYTHON) tools/refs.py

clean:
	$(RACO) pollen reset
	rm -rf public
	rm -f index.html pages/*.html essays/*/*.html blog/*/*.html assets/fonts/*.woff2 $(FONTS)
	rm -rf assets/img build data/anchors.json data/links.json data/links.local.json data/publish.txt
