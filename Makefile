# occurrentdevelopment.com
#
#   make           test, subset fonts, render, assemble public/   (offline; BUILD-2)
#   make test      typography rules (TYPE-14) and the root pass
#   make serve     Pollen project server on http://localhost:8080
#   make refresh   update the committed caches (BUILD-3): refs.bib and cite-cache.json
#   make clean     remove everything the build generates
#
# Needs: Racket with the pollen package; Python 3 with fonttools and brotli;
# ImageMagick, cwebp and avifenc for figures; pandoc for `make refresh`.

# Machine-specific settings, not committed. Set ZOTERO_BIB there to the Better
# BibTeX auto-export of your Zotero library, e.g.
#   ZOTERO_BIB = ~/Documents/References/Zotero-Library.bib
-include local.mk

RACO    ?= raco
PYTHON  ?= python3
PORT    ?= 8080

FONTS_SRC := $(wildcard assets/fonts/*.otf)
SOURCES   := $(shell find . -name '*.pm' -not -path './public/*') \
             template.html.p pollen.rkt typography.rkt
FONTS     := assets/fonts/fonts.rktd
IMAGES    := assets/img/images.json
IMG_SRC   := $(shell find pages essays -path '*/img/*' -type f 2>/dev/null)

# Files that must never reach public/ (BUILD-3a).
FORBIDDEN := -name '*-Notes.md' -o -name '*.docx' -o -name '*.graffle' -o -name '*.tex'

.PHONY: all test render publish serve refresh clean

all: test publish

test:
	$(RACO) test typography-test.rkt pollen-test.rkt
	@! grep -rn --include='*.pm' '◊quote\b' . || \
	  { echo "◊quote is not a tag (Racket's quote swallows it); use ◊blockquote"; exit 1; }

# Subset each face to the characters the site uses (TYPE-8). Writes hashed
# WOFF2 files beside the sources and a manifest the template reads.
$(FONTS): $(FONTS_SRC) $(SOURCES) tools/fonts.py
	$(PYTHON) tools/fonts.py

# Image variants for every figure (IMG-1).
$(IMAGES): $(IMG_SRC) $(SOURCES) tools/images.py
	$(PYTHON) tools/images.py

render: $(FONTS) $(IMAGES)
	$(RACO) pollen render -p index.ptree
	$(RACO) make tools/validate.rkt && racket tools/validate.rkt

# Pages render beside their sources; public/ gets them flattened to /<name>.
publish: render
	rm -rf public
	mkdir -p public/assets/fonts public/assets/icons public/assets/img public/data
	cp index.html public/
	for f in pages/*.html; do cp "$$f" public/; done
	cp assets/fonts/*.woff2 public/assets/fonts/
	cp assets/icons/*.svg public/assets/icons/
	find assets/img -type f ! -name images.json -exec cp {} public/assets/img/ \;
	cp data/anchors.json public/data/
	cp _headers public/
	@bad=$$(find public $(FORBIDDEN)); \
	  if [ -n "$$bad" ]; then echo "Refusing to publish: $$bad"; exit 1; fi

serve: $(FONTS) $(IMAGES)
	$(RACO) pollen start . $(PORT)

refresh:
	ZOTERO_BIB="$(ZOTERO_BIB)" $(PYTHON) tools/refs.py

clean:
	$(RACO) pollen reset
	rm -rf public
	rm -f index.html pages/*.html assets/fonts/*.woff2 $(FONTS)
	rm -rf assets/img data/anchors.json data/links.json
