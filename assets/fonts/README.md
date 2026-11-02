# Fonts

Libertinus 7.051 (https://github.com/alerque/libertinus), SIL Open Font License 1.1 — see `OFL.txt`, copied unchanged from the release. The release's AUTHORS.txt and FONTLOG.txt are not copied (they list contributors' email addresses); see the upstream repository.

Cormorant (https://github.com/CatharsisFonts/Cormorant), SIL Open Font License 1.1 — see `OFL-Cormorant.txt`; no reserved font name. `Cormorant-Medium.ttf` is a static instance of the Google Fonts variable file at wght 500 (fontTools `varLib.instancer`), used for the home page's masthead alone (HOME-2) and subset to its two words.

Committed: Serif Regular, Italic and Semibold, and Mono Regular, as released (OTF); Serif Display Regular from the same 7.051 release as packaged by Google Fonts (TTF), for titles (LAYOUT-2); and Cormorant Medium (TTF). `make` subsets them to WOFF2 (`tools/fonts.py`); the subsets and `fonts.rktd` are generated and not committed. The reserved font names are "Linux Libertine", "Biolinum" and "STIX Fonts", so the subsets may keep the Libertinus name.
