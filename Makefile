# occurrentdevelopment.com
#
#   make           test, subset fonts, render, assemble public/   (offline; BUILD-2)
#   make test      typography rules (TYPE-14) and the root pass
#   make test-emacs  the Emacs mode's tests (needs Emacs 29+)
#   make serve     Pollen project server on http://localhost:8080
#   make refresh   update the committed caches (BUILD-3): refs.bib, cite-cache.json, invert.json
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

FONTS_SRC := $(wildcard assets/fonts/*.otf)
# Emacs's lock files (.#name, a dangling link while a buffer is modified) are not sources.
SOURCES   := $(shell find . -name '*.pm' -not -name '.\#*' -not -path './public/*' -not -path './essays/*/support/*' -not -path './notebook/*/support/*') \
             template.html.p pollen.rkt typography.rkt
FONTS     := assets/fonts/fonts.rktd
IMAGES    := assets/img/images.json
IMG_SRC   := $(shell find pages essays notebook -path '*/img/*' -type f 2>/dev/null)

# Files that must never reach public/ (BUILD-3a).
FORBIDDEN := -name '*-Notes.md' -o -name '*.docx' -o -name '*.graffle' -o -name '*.tex'

.PHONY: all test test-emacs render publish serve refresh clean

all: test publish

test:
	$(RACO) test typography-test.rkt pollen-test.rkt
	@! grep -rn --include='*.pm' '◊quote\b' . || \
	  { echo "◊quote is not a tag (Racket's quote swallows it); use ◊blockquote"; exit 1; }

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

# The indexes and the home page list every post, so they are rebuilt
# whenever anything is.
INDEXES := pages/index.html.pm pages/essays.html.pm pages/notebook.html.pm
render: $(FONTS) $(IMAGES)
	touch $(INDEXES)
	$(RACO) pollen render -p index.ptree
	$(RACO) make tools/validate.rkt && racket tools/validate.rkt

# Pages render beside their sources; public/ gets them flattened to /<name>.
publish: render
	rm -rf public
	mkdir -p public/assets/fonts public/assets/icons public/assets/img public/assets/js public/data
	while read src dest; do mkdir -p "public/$$(dirname "$$dest")"; cp "$$src" "public/$$dest"; done < data/publish.txt
	cp assets/fonts/*.woff2 public/assets/fonts/
	cp assets/icons/*.svg public/assets/icons/
	cp assets/js/site.js assets/js/tables.js public/assets/js/
	find assets/img -type f ! -name images.json -exec cp {} public/assets/img/ \;
	cp data/anchors.json public/data/
	cp -R build/_x public/_x
	cp _headers _redirects public/
	@bad=$$(find public $(FORBIDDEN)); \
	  if [ -n "$$bad" ]; then echo "Refusing to publish: $$bad"; exit 1; fi

serve: $(FONTS) $(IMAGES)
	touch $(INDEXES)
	$(RACO) pollen start . $(PORT)

refresh:
	ZOTERO_BIB="$(ZOTERO_BIB)" $(PYTHON) tools/refs.py
	$(PYTHON) tools/invert.py

clean:
	$(RACO) pollen reset
	rm -rf public
	rm -f index.html pages/*.html essays/*/*.html notebook/*/*.html assets/fonts/*.woff2 $(FONTS)
	rm -rf assets/img build data/anchors.json data/links.json data/publish.txt
