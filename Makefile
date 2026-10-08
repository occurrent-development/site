# occurrentdevelopment.com
#
#   make           test, subset fonts, render, assemble public/   (offline; BUILD-2)
#   make test      typography rules (TYPE-14) and the root pass
#   make serve     Pollen project server on http://localhost:8080
#   make refresh   networked cache updates (BUILD-3); nothing to refresh yet
#   make clean     remove everything the build generates
#
# Needs: Racket with the pollen package; Python 3 with fonttools and brotli.

RACO    ?= raco
PYTHON  ?= python3
PORT    ?= 8080

FONTS_SRC := $(wildcard assets/fonts/*.otf)
SOURCES   := $(shell find . -name '*.pm' -not -path './public/*') \
             template.html.p pollen.rkt typography.rkt
FONTS     := assets/fonts/fonts.rktd

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

render: $(FONTS)
	$(RACO) pollen render -p index.ptree

# Pages render beside their sources; public/ gets them flattened to /<name>.
publish: render
	rm -rf public
	mkdir -p public/assets/fonts public/assets/icons
	cp index.html public/
	for f in pages/*.html; do cp "$$f" public/; done
	cp assets/fonts/*.woff2 public/assets/fonts/
	cp assets/icons/*.svg public/assets/icons/
	cp _headers public/
	@bad=$$(find public $(FORBIDDEN)); \
	  if [ -n "$$bad" ]; then echo "Refusing to publish: $$bad"; exit 1; fi

serve: $(FONTS)
	$(RACO) pollen start . $(PORT)

refresh:
	@echo "make refresh: nothing to refresh yet (citations, images and links arrive in later phases)."

clean:
	$(RACO) pollen reset
	rm -rf public
	rm -f index.html pages/*.html assets/fonts/*.woff2 $(FONTS)
