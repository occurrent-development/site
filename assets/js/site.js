// occurrentdevelopment.com — the interactive layer. IDs refer to SPEC.md.
//
// A deferred module that runs after first paint (PERF-1). Everything it
// enhances is already in the HTML and works without it: circles and links
// lead to the end matter, margin notes run in, asides are listed at the end.

const root = document.documentElement;
const page = document.querySelector(".page");
const article = document.querySelector("article");

// Firefox lays out tier XL first with the page's container units read from
// its width before the contents' column is reserved, putting the text block
// 8em too far right, and corrects it only on a later restyle, ~300 ms on.
// One restyle now corrects it at once (LAYOUT-6a, CLS §14).
if (page) { void page.offsetWidth; page.style.setProperty("--restyle", "1"); }

const store = {
  get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
  set(k, v) { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) {} },
};
const byId = (id) => document.getElementById(id);

function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) if (v != null) e.setAttribute(k, v);
  e.append(...kids.filter((k) => k != null));
  return e;
}

// The width tier, as the stylesheet's container queries see it (LAYOUT-6).
const tier = () => (article ? getComputedStyle(article).getPropertyValue("--tier").trim() : "S");
// Tiers L and XL have both margins; XL adds the contents at the window's edge.
const wide = () => ["L", "XL"].includes(tier());

// ── Theme (THEME-1, THEME-6) ──────────────────────────────────────────────

const THEMES = ["auto", "light", "dark"];
const THEME_NAMES = { auto: "Auto", light: "Light", dark: "Dark" };
const theme = () => root.dataset.theme || "auto";

function showTheme() {
  for (const b of document.querySelectorAll("[data-theme-toggle]")) {
    const c = theme();
    b.dataset.choice = c;
    b.setAttribute("aria-label", `Theme: ${THEME_NAMES[c]}. Change theme`);
    b.title = `Theme: ${THEME_NAMES[c]}`;
    b.hidden = false;
  }
}

function setTheme(c) {
  if (c === "auto") delete root.dataset.theme; else root.dataset.theme = c;
  store.set("theme", c === "auto" ? null : c);
  showTheme();
}

// ── Text size (THEME-5): five steps, the middle one the default ───────────

const SIZES = 5, MID = 2;
function size() {
  const n = Number(root.dataset.size);
  return Number.isInteger(n) && n >= 0 && n < SIZES && root.dataset.size !== undefined ? n : MID;
}

function showSize() {
  for (const b of document.querySelectorAll(".size-down")) b.disabled = size() === 0;
  for (const b of document.querySelectorAll(".size-up")) b.disabled = size() === SIZES - 1;
}

// THEME-5a: changing the size keeps the reader's place. The character at
// the start of the first line wholly visible (below the bar, if it is showing at the
// top) is found before the change and scrolled back to the same height after.
function caretAt(x, y) {
  if (document.caretPositionFromPoint) {
    const p = document.caretPositionFromPoint(x, y);
    return p && { node: p.offsetNode, offset: p.offset };
  }
  const r = document.caretRangeFromPoint?.(x, y);
  return r && { node: r.startContainer, offset: r.startOffset };
}
function charRect(node, offset) {
  const r = document.createRange();
  const end = Math.min(offset + 1, node.length);
  r.setStart(node, Math.min(offset, end)); r.setEnd(node, end);
  const rects = r.getClientRects();
  return rects[0] || r.getBoundingClientRect();
}
function readingAnchor() {
  if (!article || scrollY < 1) return null;
  const b = bar?.getBoundingClientRect();
  const top = b && bar.classList.contains("is-shown") && b.top < 1 ? b.bottom : 0;
  const a = article.getBoundingClientRect();
  for (let y = top + 2; y < top + 80; y += 4) {
    for (const x of [a.left + a.width * 0.25, a.left + a.width * 0.5]) {
      const c = caretAt(x, y);
      if (c?.node?.nodeType === Node.TEXT_NODE && article.contains(c.node) && c.node.length) {
        // the first line wholly in view; back to its start
        let { node, offset } = c;
        const lineTop = charRect(node, offset).top;
        if (lineTop < top - 1) continue;
        while (offset > 0 && Math.abs(charRect(node, offset - 1).top - lineTop) < 2) offset--;
        return { node, offset, top: charRect(node, offset).top };
      }
    }
  }
  // no text at the top (a figure, a table): fall back to the element there
  const elAt = document.elementFromPoint(a.left + a.width / 2, top + 2);
  return elAt && article.contains(elAt) ? { el: elAt, top: elAt.getBoundingClientRect().top } : null;
}
// A new size can change the width tier, and the margin is then rebuilt a
// frame later (scheduleLayout), reflowing the text again; so the pin is
// re-applied after each layout pass for the next half second.
let placeKeptAt = 0;   // the scroll keepPlace makes must not hide the bar
let repin = null;
function keepPlace(change) {
  const anchor = readingAnchor();
  change();
  if (!anchor) return;
  const pin = () => {
    placeKeptAt = performance.now();
    const now = anchor.el ? anchor.el.getBoundingClientRect().top : charRect(anchor.node, anchor.offset).top;
    if (Math.abs(now - anchor.top) >= 1) scrollTo({ top: scrollY + now - anchor.top, behavior: "instant" });
  };
  pin();
  repin = pin;
  setTimeout(() => { if (repin === pin) repin = null; }, 500);
}

function setSize(n) {
  n = Math.max(0, Math.min(SIZES - 1, n));
  keepPlace(() => {
    if (n === MID) delete root.dataset.size; else root.dataset.size = String(n);
  });
  store.set("size", n === MID ? null : String(n));
  showSize();
  scheduleLayout();   // an open popup stays open and steps with the text (THEME-5b)
}

addEventListener("storage", (e) => {
  if (e.key === "theme") {
    if (e.newValue) root.dataset.theme = e.newValue; else delete root.dataset.theme;
    showTheme();
  }
  if (e.key === "size") {
    keepPlace(() => { if (e.newValue) root.dataset.size = e.newValue; else delete root.dataset.size; });
    showSize();
    scheduleLayout();
  }
});

// ── Content for popups (POP-7) ────────────────────────────────────────────

// A display copy: no ids, back-links, self-links or hidden aside copies.
function clean(node) {
  const c = node.cloneNode(true);
  c.removeAttribute("id");
  for (const e of c.querySelectorAll("[id]")) e.removeAttribute("id");
  for (const e of c.querySelectorAll(".back, .self, .aside[hidden], .stub, .toc-mark, .expand, .sticky-head")) e.remove();
  for (const e of c.querySelectorAll(".in-margin")) { e.classList.remove("in-margin"); e.removeAttribute("style"); }   // margin notes, run in again
  return c;
}

function termItem(target) {
  const c = clean(byId(target));
  const dfn = c.querySelector("dfn");
  const title = dfn ? dfn.textContent : "Definition";
  if (dfn) {
    const next = dfn.nextSibling;
    dfn.remove();
    if (next && next.nodeType === 3) next.textContent = next.textContent.replace(/^\.\s*/, "");
  }
  const body = el("div", { class: "popup-term" }, c.querySelector(".definition"));
  const more = c.querySelector(".term-more");
  if (more) {
    // TERM-3: More expands in place
    more.hidden = true;
    const btn = el("button", { type: "button", class: "popup-more", "aria-expanded": "false" }, "More");
    btn.addEventListener("click", () => { more.hidden = false; btn.parentElement.remove(); });
    body.append(el("p", {}, btn), more);
  }
  const see = c.querySelector(".see-also");
  if (see) body.append(see);
  return { title, head: title, body };
}

function item(target) {
  const src = byId(target);
  if (!src && !target.startsWith("aside-")) return null;
  if (target.startsWith("note-")) {
    const n = target.slice(5);
    const body = el("div", {}, el("p", {}, ...clean(src).childNodes));
    // A full note is already the reference; a short one gets the full entry (POP-7).
    const bib = src.dataset.form === "short" && src.dataset.bib && byId(src.dataset.bib);
    if (bib) body.append(el("p", { class: "popup-bib" }, ...clean(bib).childNodes));
    return { title: `Note ${n}`, head: `Note ${n}`, body };
  }
  if (target.startsWith("bib-")) {
    // CITE-7: unnumbered, so no heading
    return { title: "Reference", head: null, body: el("p", {}, ...clean(src).childNodes) };
  }
  if (target.startsWith("term-")) return termItem(target);
  if (target.startsWith("aside-")) {
    const text = byId("aside-text-" + target.slice(6));
    if (!text) return null;
    const c = clean(text);
    return { title: "Aside", head: "Aside", body: el("p", {}, ...c.childNodes) };
  }
  return null;
}

// A circle: everything it opens, in source order, separated by a hairline (MARK-1c).
function circleContent(t) {
  const items = t.dataset.targets.split(" ").map(item).filter(Boolean);
  const body = el("div");
  items.forEach((it, i) => {
    if (i) body.append(el("hr", { class: "popup-sep" }));
    if (items.length > 1 && it.head) body.append(el("p", { class: "popup-item-head" }, it.head));
    body.append(it.body);
  });
  return { title: items.map((i) => i.title).join(" · "), body, items };
}

function sectionContent(id) {
  const target = byId(id);
  if (!target) return null;
  const source = target.matches("section") ? target : target.closest("p, li, figure, blockquote") || target;
  const c = clean(source);
  const h = c.querySelector(":scope > h2, :scope > h3, :scope > h4, :scope > .exhibit-title");
  const title = h ? h.textContent.replace(/§\s*$/, "").trim() : "";
  if (h) h.remove();
  for (const x of c.querySelectorAll(".circle-link, .circle")) x.remove();
  return { title, plain: source.classList.contains("exhibit"), body: el("div", {}, ...c.childNodes) };
}

// Cross-page extracts are build-time fragments, fetched once (POP-7).
const fragments = new Map();
function fragmentUrl(href) {
  const u = new URL(href, location.href);
  const slug = u.pathname.replace(/^\//, "").replace(/\.html$/, "");
  return `/_x/${slug}/${u.hash.slice(1) || "_page"}.frag`;
}
function fetchFragment(href) {
  const url = fragmentUrl(href);
  if (!fragments.has(url)) {
    fragments.set(url, fetch(url).then((r) => (r.ok ? r.text() : null)).catch(() => null));
  }
  return fragments.get(url);
}
async function xrefContent(a) {
  const html = await fetchFragment(a.getAttribute("href"));
  if (!html) return { title: linkText(a), url: a.href, body: el("p", {}, "This extract could not be loaded.") };
  const t = document.createElement("template");
  t.innerHTML = html;
  const h = t.content.querySelector("h1, h2, h3, h4");
  const title = h ? h.textContent.trim() : linkText(a);
  if (h) h.remove();
  return { title, url: a.href, body: el("div", {}, ...t.content.childNodes) };
}

function linkText(a) {
  const c = a.cloneNode(true);
  for (const x of c.querySelectorAll(".vh")) x.remove();
  return c.textContent.replace(/⁠/g, "").trim();
}

// External link cards: facts and Ryan's note only (§11.1).
function cardContent(a) {
  const d = a.dataset;
  const u = new URL(a.href);
  const facts = [d.author, d.publisher, d.date, d.type].filter(Boolean).join(" · ");
  const body = el("div", { class: "card" },
    el("p", { class: "card-domain" }, u.hostname.replace(/^www\./, "")),
    facts ? el("p", { class: "card-facts" }, facts) : null,
    d.doi ? el("p", { class: "card-facts" }, `DOI ${d.doi}`) : null,
    d.dead ? el("p", { class: "card-facts" }, `Original offline since ${d.dead}`) : null,
    d.note ? el("p", { class: "card-note" }, d.note) : null,
    d.wayback ? el("p", {}, el("a", { href: d.wayback, target: "_blank", rel: "noopener" }, "Wayback copy")) : null);
  return { title: d.title || linkText(a), url: a.href, body };
}

const TRIGGERS = ".circle-link, a.term[data-targets], a.aside-phrase[data-targets], a.link.same, a.link.xref, a.link.ext";
function kindOf(t) {
  if (t.matches(".circle-link, a.term[data-targets], a.aside-phrase[data-targets]")) return "circle";
  if (t.matches("a.link.same")) return "same";
  if (t.matches("a.link.xref")) return "xref";
  return "ext";
}
async function contentFor(t) {
  switch (kindOf(t)) {
    case "circle": return circleContent(t);
    case "same": return sectionContent(t.getAttribute("href").slice(1));
    case "xref": return xrefContent(t);
    default: return cardContent(t);
  }
}

// ── The open popup: a popup, a popin, or the bar's contents ─────────────────

let open = null;      // { box, trigger, pinned, mode, shade }
let openTimer = 0, closeTimer = 0, seq = 0;
const touch = matchMedia("(hover: none)");   // POP-5, BAR-1

// THEME-5b: popups are mounted in the scaled wrapper, so they step with the text.
const mount = () => document.querySelector(".frame") || document.body;

const SVG = "http://www.w3.org/2000/svg";
function icon(d) {
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", "0 0 12 12");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(SVG, "path");
  for (const [k, v] of Object.entries({ d, fill: "none", stroke: "currentColor", "stroke-width": "1.2",
    "stroke-linecap": "round", "stroke-linejoin": "round" })) path.setAttribute(k, v);
  svg.append(path);
  return svg;
}
const CROSS = "M2.5 2.5l7 7M9.5 2.5l-7 7";
const BACK = "M7.5 2.5 4 6l3.5 3.5";

// ASIDE-2: a circle is filled while what it opens is open.
// ASIDE-2, ASIDE-8: while open, the circle is filled and a phrase keeps the accent.
function fill(t, on) {
  t?.querySelector?.(".circle")?.classList.toggle("is-open", on);
  if (t?.matches?.("a.aside-phrase")) t.classList.toggle("is-open", on);
}

function buildPopup(c, pinned) {
  const id = `popup-title-${++seq}`;
  const box = el("div", { class: "popup", role: pinned ? "dialog" : "tooltip", "aria-labelledby": id, tabindex: "-1" });
  const bar = el("div", { class: "popup-bar" },
    el("span", { class: c.plain ? "popup-title plain" : "popup-title", id }, c.title || ""),
    c.url ? el("a", { class: "popup-open", href: c.url, target: "_blank", rel: "noopener" }, "Open in new tab") : null,
    el("button", { type: "button", class: "popup-close", "aria-label": "Close" }, icon(CROSS)));
  box.append(bar, el("div", { class: "popup-body" }, c.body));
  return box;
}

// POP-2: in the viewport, never over the element that opened it.
function placeFloat(box, t) {
  mount().append(box);
  const r = t.getBoundingClientRect();
  const vw = root.clientWidth, vh = innerHeight, gap = 6, edge = 8;
  const below = vh - r.bottom - gap - edge, above = r.top - gap - edge;
  const roomBelow = box.offsetHeight <= below || below >= above;
  box.style.maxHeight = `${Math.max(120, Math.min(box.offsetHeight, roomBelow ? below : above))}px`;
  const bw = box.offsetWidth, bh = box.offsetHeight;
  const left = Math.min(Math.max(edge, r.left + r.width / 2 - bw / 2), vw - bw - edge);
  const top = roomBelow ? r.bottom + gap : r.top - gap - bh;
  box.style.left = `${left + scrollX}px`;
  box.style.top = `${top + scrollY}px`;
}

// POP-5: a sheet from the bottom on touch devices; the page stays put.
function placePopin(box) {
  box.classList.add("is-popin");
  const shade = el("div", { class: "popin-shade" });
  mount().append(shade, box);
  root.style.overflow = "hidden";
  let y0 = null, dy = 0;
  const bar = box.querySelector(".popup-bar");
  bar.addEventListener("touchstart", (e) => { y0 = e.touches[0].clientY; dy = 0; }, { passive: true });
  bar.addEventListener("touchmove", (e) => {
    if (y0 == null) return;
    dy = Math.max(0, e.touches[0].clientY - y0);
    box.style.transform = `translateY(${dy}px)`;
  }, { passive: true });
  bar.addEventListener("touchend", () => {
    if (dy > 70) close(); else box.style.transform = "";
    y0 = null;
  });
  return shade;
}

async function openFor(t, { pinned = false, focus = false } = {}) {
  clearTimeout(closeTimer);
  if (open && open.trigger === t) {
    if (pinned) pin();
    if (focus) open.box.focus();
    return;
  }
  const c = await contentFor(t);
  if (!c || (open && open.trigger === t)) return;
  close();
  const box = buildPopup(c, pinned);
  let shade = null, mode = "float";
  if (touch.matches) { shade = placePopin(box); mode = "popin"; pinned = true; box.setAttribute("role", "dialog"); }
  else placeFloat(box, t);
  open = { box, trigger: t, pinned, mode, shade };
  t.setAttribute("aria-expanded", "true");
  if (pinned) fill(t, true);
  if (focus || mode === "popin") box.focus({ preventScroll: true });
}

function pin() {
  if (!open) return;
  open.pinned = true;
  open.box.setAttribute("role", "dialog");
  fill(open.trigger, true);
}

function close({ returnFocus = false } = {}) {
  clearTimeout(openTimer);
  clearTimeout(closeTimer);
  if (!open) return;
  const o = open;
  open = null;
  o.box.remove();
  o.shade?.remove();
  if (o.mode === "popin") root.style.overflow = "";
  o.trigger.setAttribute?.("aria-expanded", "false");
  fill(o.trigger, false);
  if (o.mode === "toc") bar?.classList.remove("toc-open");
  if (returnFocus) o.trigger.focus?.();
}

function scheduleClose() {
  clearTimeout(closeTimer);
  if (open && !open.pinned) closeTimer = setTimeout(close, 250);
}

// POP-6, TERM-7: a circle inside a popup replaces its content; Back, in the
// title bar, restores it.
function replaceContent(box, t) {
  const body = box.querySelector(".popup-body");
  const c = circleContent(t);
  if (!body || !c.items.length) return;
  const title = box.querySelector(".popup-title");
  const saved = { nodes: [...body.childNodes], title: title?.textContent };
  box.querySelector(".popup-back")?.remove();
  const back = el("button", { type: "button", class: "popup-back", "aria-label": "Back" }, icon(BACK), "Back");
  back.addEventListener("click", (e) => {
    e.stopPropagation();
    body.replaceChildren(...saved.nodes);
    if (title) title.textContent = saved.title;
    back.remove();
    box.focus({ preventScroll: true });
  });
  box.querySelector(".popup-bar").prepend(back);
  body.replaceChildren(c.body);   // the title bar names it
  if (title) title.textContent = c.title;
}

// ── Expanded figures and tables (IMG-8) ───────────────────────────────────

const EXPAND = "M7 2h3v3M10 2 6.5 5.5M5 10H2V7M2 10l3.5-3.5";
let lightbox = null;   // { box, shade, from }

function setupExhibits() {
  for (const fig of article?.querySelectorAll(".exhibit") || []) {
    const label = fig.querySelector(".exhibit-label")?.textContent.replace(/\u00A0/g, " ") || "";
    const b = el("button", { type: "button", class: "expand", "aria-label": `Expand ${label}`.trim(), title: "Expand" }, icon(EXPAND));
    fig.querySelector(".exhibit-body")?.append(b);
  }
}

function openLightbox(fig, from) {
  closeLightbox();
  close();
  const id = `lb-title-${++seq}`;
  const title = clean(fig.querySelector(".exhibit-title"));
  const stage = el("div", { class: "lb-stage" });
  const body = clean(fig.querySelector(".exhibit-body"));
  // the largest variant the window wants, not the column's
  for (const x of body.querySelectorAll("source, img")) if (x.hasAttribute("sizes")) x.setAttribute("sizes", "100vw");
  for (const img of body.querySelectorAll("img")) { img.removeAttribute("loading"); img.removeAttribute("width"); img.removeAttribute("height"); }
  // a table's sort buttons would do nothing here: keep their words
  for (const btn of body.querySelectorAll("th button.sort")) { btn.querySelector(".sort-mark")?.remove(); btn.replaceWith(...btn.childNodes); }
  // a table keeps its booktabs rules, at body size whatever its size in the text
  if (fig.classList.contains("table-wrap")) stage.classList.add("is-table", "table-wrap");
  stage.append(...body.childNodes);
  const meta = fig.querySelector(".exhibit-meta");
  const box = el("div", { class: "lightbox", role: "dialog", "aria-modal": "true", "aria-labelledby": id, tabindex: "-1" },
    el("div", { class: "lb-head" },
      el("span", { class: "lb-title", id }, ...title.childNodes),
      el("button", { type: "button", class: "lb-close", "aria-label": "Close" }, icon(CROSS))),
    stage,
    el("div", { class: "lb-foot" }, ...(meta ? clean(meta).childNodes : [])));
  if (fig.dataset.invert) box.dataset.invert = fig.dataset.invert;
  const shade = el("div", { class: "lightbox-shade" });
  mount().append(shade, box);
  root.style.overflow = "hidden";
  lightbox = { box, shade, from };
  box.querySelector(".lb-close").focus({ preventScroll: true });
}

function closeLightbox() {
  if (!lightbox) return;
  const { box, shade, from } = lightbox;
  lightbox = null;
  box.remove();
  shade.remove();
  root.style.overflow = "";
  from?.focus?.({ preventScroll: true });
}

// ── The margin item: an aside or definition expanded in place (ASIDE-3) ────

let marginOpen = null;      // the pinned item: { stub, trigger }
let marginPreview = null;   // the item hover is previewing (ASIDE-3): { stub, trigger }
let previewTimer = 0, previewCloseTimer = 0;

// The stub a trigger opens, in tiers L and XL, when the trigger is in the text (a
// circle inside an open margin item opens a popup instead, POP-6).
function stubFor(t) {
  if (!wide() || !t || t.closest(".in-margin")) return null;
  return t._stub?.isConnected ? t._stub : null;
}

// Grow a stub in place, or fold it again. A pinned item fills its circle; a
// preview does not (ASIDE-2), and shows a definition's short text only:
// More and see-also make sense once the reader has chosen to stay.
function expandStub(stub, pinned) {
  const t = stub._trigger;
  stub.classList.add("is-open");
  stub.classList.toggle("is-preview", !pinned);
  stub.setAttribute("aria-expanded", "true");
  t?.setAttribute("aria-expanded", "true");
  if (pinned) fill(t, true);
}
function foldStub(stub) {
  const t = stub._trigger;
  stub.classList.remove("is-open", "is-preview");
  stub.setAttribute("aria-expanded", "false");
  stub.scrollTop = 0;
  for (const m of stub.querySelectorAll(".term-more")) m.hidden = true;     // More folds again
  for (const l of stub.querySelectorAll(".stub-more-line")) l.hidden = false;
  t?.setAttribute("aria-expanded", "false");
  fill(t, false);
}

// Click or Enter pins (ASIDE-3): a previewed item becomes the pinned one.
function toggleMargin(stub, { focus = false } = {}) {
  if (marginOpen && marginOpen.stub === stub) { collapseMargin({ returnFocus: focus }); return; }
  if (marginPreview && marginPreview.stub === stub) { clearTimeout(previewCloseTimer); marginPreview = null; }
  collapseMargin();
  if (stub.dataset.full) { if (focus) stub.focus(); return; }   // shown in full; never collapses
  expandStub(stub, true);
  marginOpen = { stub, trigger: stub._trigger };
  positionMargin();
  if (focus) stub.focus({ preventScroll: true });
}

function collapseMargin({ returnFocus = false } = {}) {
  if (!marginOpen) return;
  const { stub, trigger } = marginOpen;
  marginOpen = null;
  foldStub(stub);
  positionMargin();
  if (returnFocus) (trigger || stub).focus?.();
}

// ASIDE-3: hover previews, after the popup delay, so a pointer sweeping
// across a line of circles opens nothing. A preview never takes focus, so
// Esc and Tab stay where the reader left them.
function previewMargin(stub) {
  if (!stub?.isConnected || !wide() || stub.dataset.full) return;
  if (marginOpen?.stub === stub || marginPreview?.stub === stub) return;
  endPreview({ layout: false });
  expandStub(stub, false);
  marginPreview = { stub, trigger: stub._trigger };
  highlight(stub._trigger, true, stub);
  positionMargin();
}
function endPreview({ layout = true } = {}) {
  clearTimeout(previewTimer);
  clearTimeout(previewCloseTimer);
  if (!marginPreview) return;
  const { stub, trigger } = marginPreview;
  marginPreview = null;
  foldStub(stub);
  highlight(trigger, false, stub);
  if (layout) positionMargin();
}
function schedulePreview(stub) {
  clearTimeout(previewTimer);
  clearTimeout(previewCloseTimer);
  if (marginPreview?.stub === stub || marginOpen?.stub === stub || stub.dataset.full) return;
  previewTimer = setTimeout(() => previewMargin(stub), 300);
}
// The preview closes ~250 ms after the pointer has left circle and stub
// alike, unless it has gone into a popup opened from inside the preview.
function schedulePreviewEnd() {
  clearTimeout(previewTimer);
  clearTimeout(previewCloseTimer);
  if (!marginPreview) return;
  previewCloseTimer = setTimeout(() => {
    const p = marginPreview;
    if (!p) return;
    const inside = (x) => x && (x.matches(":hover") || x.contains(document.activeElement));
    if (inside(p.stub) || inside(p.trigger)) return;
    if (open && p.stub.contains(open.trigger) && open.box.matches(":hover")) return;
    endPreview();
  }, 250);
}

// ── Events ────────────────────────────────────────────────────────────────

document.addEventListener("click", (e) => {
  if (lightbox) {
    if (e.target.closest(".lb-close") || e.target.closest(".lightbox-shade")) { closeLightbox(); return; }
    // touch: a tap on the figure shows or hides the words over it
    if (touch.matches && e.target.closest(".lightbox") && !e.target.closest("a, button")) lightbox.box.classList.toggle("show-words");
    return;
  }
  const ex = e.target.closest(".expand");
  if (ex) { e.preventDefault(); openLightbox(ex.closest(".exhibit"), ex); return; }
  if (e.target.closest("[data-theme-toggle]")) { setTheme(THEMES[(THEMES.indexOf(theme()) + 1) % 3]); return; }
  if (e.target.closest(".size-down")) { setSize(size() - 1); return; }
  if (e.target.closest(".size-up")) { setSize(size() + 1); return; }
  if (e.target.closest(".popup-close")) { close({ returnFocus: true }); return; }
  if (e.target.closest(".bar-section")) { e.preventDefault(); toggleToc(); return; }

  const t = e.target.closest(TRIGGERS);
  const stub = e.target.closest(".stub");

  // A collapsed or previewed stub is pinned wherever it is clicked (ASIDE-3).
  if (stub && (!stub.classList.contains("is-open") || stub.classList.contains("is-preview")) && !stub.dataset.full
      && !e.target.closest("a, button")) {
    e.preventDefault();
    close();
    toggleMargin(stub);
    return;
  }

  if (t) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return; // LINK-3: native tabs
    const inPopup = e.target.closest(".popup");
    if (inPopup && kindOf(t) === "circle") { e.preventDefault(); replaceContent(inPopup, t); return; }
    if (inPopup) { close(); return; }   // other links inside a popup simply navigate
    e.preventDefault();
    const s = stubFor(t);
    if (s) { close(); toggleMargin(s, { focus: e.detail === 0 }); return; }
    if (open && open.trigger === t && open.pinned) { close(); return; }
    openFor(t, { pinned: true, focus: e.detail === 0 });
    return;
  }

  // Clicking the text of an open item closes it ("click again"), unless the
  // reader was selecting.
  if (stub && stub.classList.contains("is-open") && !e.target.closest("button, a")) {
    if (!String(getSelection?.() || "")) collapseMargin();
    return;
  }

  // A contents link in the bar's popup: let it navigate (BAR-2), then close.
  if (open && open.mode === "toc" && e.target.closest(".popup a[href^='#']")) { close(); return; }
  if (open && !e.target.closest(".popup, .bar")) close();
});

document.addEventListener("keydown", (e) => {
  if (lightbox) {
    if (e.key === "Escape") { e.preventDefault(); closeLightbox(); return; }
    if (e.key === "Tab") {   // focus stays in the dialog
      const f = [...lightbox.box.querySelectorAll("a[href], button, [tabindex='0']")];
      const i = f.indexOf(document.activeElement);
      if (e.shiftKey && i <= 0) { e.preventDefault(); f[f.length - 1]?.focus(); }
      else if (!e.shiftKey && i === f.length - 1) { e.preventDefault(); f[0]?.focus(); }
    }
    return;
  }
  if (e.key === "Escape") {
    if (open) { close({ returnFocus: true }); return; }
    if (marginOpen) { collapseMargin({ returnFocus: true }); return; }
    if (marginPreview) { endPreview(); return; }
  }
  const stub = e.target.closest?.(".stub");
  if (stub && e.target === stub && (e.key === "Enter" || e.key === " ")) {
    e.preventDefault();
    close();
    toggleMargin(stub, { focus: true });
  }
});

// Hover: popups open after ~300 ms and close ~250 ms after leaving both
// (§11 table). Hover never opens a margin item; it only pairs circle and
// stub by colour (ASIDE-3).
document.addEventListener("pointerover", (e) => {
  if (e.pointerType !== "mouse" || touch.matches) return;
  const t = e.target.closest(TRIGGERS);
  if (lightbox) return;
  if (t && !t.closest(".popup, .bar")) {
    const s = stubFor(t);
    highlight(t, true, s);
    if (s) { schedulePreview(s); return; }
    if (kindOf(t) === "xref") fetchFragment(t.getAttribute("href"));   // prefetch
    clearTimeout(closeTimer);
    if (open && open.trigger === t) return;
    clearTimeout(openTimer);
    openTimer = setTimeout(() => { if (!(open && open.pinned)) openFor(t); }, 300);
    return;
  }
  const stub = e.target.closest(".stub");
  if (stub) {
    highlight(stub._trigger, true, stub);
    if (wide() && !stub.dataset.full) schedulePreview(stub);
  }
  if (e.target.closest(".popup")) { clearTimeout(closeTimer); clearTimeout(previewCloseTimer); }
});

document.addEventListener("pointerout", (e) => {
  if (e.pointerType !== "mouse") return;
  const r = e.relatedTarget;
  // ASIDE-3: a margin item's circle and its stub count as one place for
  // hover, whichever element inside them the pointer leaves from.
  const item = e.target.closest?.(".stub") || stubFor(e.target.closest?.(TRIGGERS));
  if (item) {
    const staying = r && (item.contains(r) || item._trigger?.contains(r));
    if (!staying) {
      clearTimeout(previewTimer);
      if (marginPreview?.stub === item) schedulePreviewEnd();
      else highlight(item._trigger, false, item);
    }
  }
  const from = e.target.closest(TRIGGERS + ", .popup, .stub");
  if (!from) return;
  const to = r?.closest?.(TRIGGERS + ", .popup, .stub");
  if (to === from) return;
  if (from.matches(".stub") || (item && from === item._trigger)) return;   // handled above
  if (from.matches(TRIGGERS)) highlight(from, false, null);
  if (from.matches(".popup") && marginPreview) schedulePreviewEnd();
  clearTimeout(openTimer);
  if (open && to && (to === open.trigger || to === open.box)) return;
  scheduleClose();
});

// ASIDE-2: a circle (or term) and its stub take the accent together.
function highlight(trigger, on, stub) {
  trigger?.classList.toggle("hl", on);
  stub?.classList.toggle("hl", on);
}

// ── The margin, tier L (POP-8, ASIDE-3/4, TERM-3, MNOTE-2/4, IMG-2) ────────

let currentTier = null;

// The aside's circle, by its target.
function circleFor(stub) {
  const id = "aside-" + stub.id.replace("aside-text-", "");
  // a circle, or a phrase aside with its circle (ASIDE-8)
  return [...article.querySelectorAll(".circle-link, a.aside-phrase[data-targets]")].find((c) => c.dataset.targets.split(" ").includes(id)) || null;
}

// TERM-3: a definition's stub, built from the Terms store: the headword and
// the definition on one line; More and see-also below, shown when open.
function defStub(t) {
  const src = byId(t.dataset.targets);
  if (!src) return null;
  const c = clean(src);
  const dfn = c.querySelector("dfn");
  const head = dfn ? dfn.textContent : "";
  if (dfn) {
    const next = dfn.nextSibling;
    dfn.remove();
    if (next && next.nodeType === 3) next.textContent = next.textContent.replace(/^\.\s*/, "");
  }
  const def = c.querySelector(".definition");
  const text = el("span", { class: "stub-text" }, el("span", { class: "stub-head" }, head), " ", ...(def ? def.childNodes : []));
  const extra = el("span", { class: "stub-extra" });
  const more = c.querySelector(".term-more");
  if (more) {
    more.hidden = true;
    const btn = el("button", { type: "button", class: "popup-more" }, "More");
    const line = el("span", { class: "stub-more-line" }, btn);
    btn.addEventListener("click", (e) => { e.stopPropagation(); more.hidden = false; line.hidden = true; positionMargin(); });
    extra.append(line, more);
  }
  const see = c.querySelector(".see-also");
  if (see) extra.append(see);
  const s = el("span", { class: "in-margin stub def-stub", tabindex: "0", role: "button", "aria-expanded": "false" }, text);
  if (extra.childNodes.length) s.append(extra);
  return s;
}

function setupMargin() {
  const L = wide();
  if (L === ["L", "XL"].includes(currentTier) && currentTier !== null) return;
  collapseMargin();   // a popup stays open: popups exist at every tier
  endPreview({ layout: false });
  if (!article) return;
  for (const a of article.querySelectorAll(".aside[id^='aside-text-']")) {
    if (a.closest("#asides")) continue;
    const t = circleFor(a);
    if (L) {
      a.hidden = false;
      a.classList.add("in-margin", "stub");
      a.tabIndex = 0;
      a.setAttribute("role", "button");
      a.setAttribute("aria-expanded", "false");
      a._trigger = t;
      if (t) t._stub = a;
    } else {
      a.hidden = true;
      a.classList.remove("in-margin", "stub", "is-full", "is-open", "hl");
      a.removeAttribute("tabindex");
      a.removeAttribute("role");
      a.removeAttribute("aria-expanded");
      delete a.dataset.full;
      a.removeAttribute("style");
      if (t) t._stub = null;
    }
  }
  // TERM-3: definitions in the text get stubs too (not those inside an aside)
  for (const s of article.querySelectorAll(".def-stub")) { if (s._trigger) s._trigger._stub = null; s.remove(); }
  if (L) {
    for (const t of article.querySelectorAll("a.term[data-targets]")) {
      if (t.closest(".aside, .endmatter, .in-margin, nav.toc, .exhibit-title, .exhibit-meta") || t.dataset.targets.includes(" ")) continue;
      const s = defStub(t);
      if (!s) continue;
      t.after(s);
      s._trigger = t;
      t._stub = s;
    }
  }
  for (const m of article.querySelectorAll(".margin-note")) {
    m.classList.toggle("in-margin", L);
    if (!L) m.removeAttribute("style");
  }
  if (!L) for (const x of article.querySelectorAll(".exhibit-title, .exhibit-meta, .header-meta")) x.style.transform = "";
  if (!L) alignContents();
}

// The bottom of the first (or last) visible character in a run of text
// nodes: its baseline, near enough.
function charBottom(nodes, fromEnd = false) {
  for (const n of fromEnd ? nodes.reverse() : nodes) {
    const m = fromEnd ? n.data.match(/\S(?=\s*$)/) : n.data.match(/\S/);
    if (!m) continue;
    const r = document.createRange();
    r.setStart(n, m.index); r.setEnd(n, m.index + 1);
    const b = r.getBoundingClientRect();
    if (b.height) return b.bottom;
  }
  return null;
}
function textNodes(root, filter = () => true) {
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const out = [];
  for (let n; (n = w.nextNode());) if (filter(n)) out.push(n);
  return out;
}

// The first baseline of an element, exactly: an empty inline-block's bottom
// sits on the baseline of its line, so one is put before the first text
// and measured. Character boxes would not do: their bottoms are the
// descent below the baseline, which differs between sizes and faces.
function firstBaseline(e) {
  const n = textNodes(e, (t) => t.data.trim() && !t.parentElement.closest(".vh"))[0];
  if (!n) return e.getBoundingClientRect().top;
  const probe = el("span", { "aria-hidden": "true" });
  probe.style.cssText = "display:inline-block;width:0;height:0;vertical-align:baseline;margin:0;padding:0";
  const lead = n.data.match(/^\s*/)[0].length;
  const at = lead ? n.splitText(lead) : n;
  at.before(probe);
  const y = probe.getBoundingClientRect().top;
  probe.remove();
  if (lead) n.parentNode.normalize();
  return y;
}

// LAYOUT-1a, TOC-2: in tier XL the "Contents" label sits on the title's
// first baseline.
function alignContents() {
  const toc = article?.querySelector("nav.toc");
  if (!toc) return;
  toc.style.top = "";
  const title = article.querySelector(".essay-header:not(.sample) h1");
  const label = toc.querySelector(".toc-title");
  if (tier() !== "XL" || !title || !label || getComputedStyle(toc).position !== "absolute") return;
  toc.style.top = `${firstBaseline(title) - firstBaseline(label)}px`;
}

// MNOTE-2/4/6: margin notes in the left margin, right-aligned against the
// column, each level with the line on which its anchor begins: the first
// visible character after the note (the paragraph, item or sentence it
// opens). Not the note's own static place: when a line breaks just after
// "end.", that is the end of the line above. The left margin is its own
// column: notes collide only with each other, the later moving down just
// enough to clear, and nothing in the right margin moves them.
function positionNotes() {
  const notes = [...article.querySelectorAll(".in-margin.margin-note")];
  if (!notes.length) return;
  const col = article.getBoundingClientRect().left;   // the column's left edge
  const page_ = getComputedStyle(article);
  const width = parseFloat(page_.getPropertyValue("--left-margin"));
  const gap = parseFloat(getComputedStyle(page).getPropertyValue("--margin-gap")) * parseFloat(page_.fontSize);
  for (const n of notes) n.style.transform = "";
  const placed = notes.map((n) => {
    // inside a list item the containing block is the item, not the article
    const cb = n.offsetParent || article;
    const left = col - gap - width - cb.getBoundingClientRect().left - cb.clientLeft;
    Object.assign(n.style, { left: `${left}px`, width: `${width}px` });
    const block = n.parentElement;
    const inNote = (t) => n.contains(t);
    const all = textNodes(block, (t) => !inNote(t) && !t.parentElement.closest(".aside, .stub, .vh, .margin-note"));
    const after = all.filter((t) => n.compareDocumentPosition(t) & Node.DOCUMENT_POSITION_FOLLOWING);
    const before = all.filter((t) => n.compareDocumentPosition(t) & Node.DOCUMENT_POSITION_PRECEDING);
    const target = charBottom(after) ?? charBottom(before, true);
    const own = charBottom(textNodes(n));
    const r = n.getBoundingClientRect();
    const dy = target != null && own != null ? target - own : 0;
    return { n, top: r.top + dy, h: r.height, dy };
  }).sort((a, b) => a.top - b.top);
  const space = notes.length ? parseFloat(getComputedStyle(notes[0]).lineHeight) * 0.25 : 4;
  let last = -Infinity;
  for (const p of placed) {
    const y = Math.max(p.top, last + space);
    p.dy += y - p.top;
    last = y + p.h;
    if (Math.abs(p.dy) > 0.5) p.n.style.transform = `translateY(${p.dy}px)`;
  }
}

// ASIDE-4, IMG-7: the words of figures and tables and the header's block
// hold their place in the right margin, and stubs fit around them, moving down just enough to
// clear; then an open item pushes whatever is below it down, as far as it
// needs, and everything returns when it closes.
function positionMargin() {
  if (!wide() || !article) return;
  positionNotes();
  const rect = (x) => x.getBoundingClientRect();
  const stubs = [...article.querySelectorAll(".in-margin.stub")];
  const exhibits = [...article.querySelectorAll(".exhibit")]
    .map((x) => [x.querySelector(".exhibit-title"), x.querySelector(".exhibit-meta")].filter(Boolean));
  const headers = [...article.querySelectorAll(".header-meta")];
  for (const e of [...stubs, ...exhibits.flat(), ...headers]) e.style.transform = "";
  // ASIDE-3: an item that fits in two margin lines is shown in full
  // Stubs can sit in smaller text (a table), where the stylesheet's em would
  // be wrong; so their place and size are set from the article's.
  const fs = parseFloat(getComputedStyle(article).fontSize);
  const v = (name) => parseFloat(getComputedStyle(page).getPropertyValue(name)) * fs;
  for (const st of stubs) {
    Object.assign(st.style, { left: `${v("--measure") + v("--margin-gap")}px`, width: getComputedStyle(article).getPropertyValue("--margin"), fontSize: `${0.85 * fs}px` });
    if (st.classList.contains("is-open")) continue;
    st.classList.add("is-full");
    const lh = parseFloat(getComputedStyle(st).lineHeight);
    if (st.offsetHeight <= 2 * lh + 1 && !st.querySelector(".stub-extra")) st.dataset.full = "1";
    else { delete st.dataset.full; st.classList.remove("is-full"); }
  }
  // Items: { els, top, h, fixed }. A caption block has no height of its own,
  // so its extent is its children's.
  const extent = (els) => {
    const rs = els.flatMap((e) => [rect(e), ...[...e.children].map(rect)]).filter((r) => r.height);
    return rs.length ? [Math.min(...rs.map((r) => r.top)), Math.max(...rs.map((r) => r.bottom))] : [rect(els[0]).top, rect(els[0]).top];
  };
  // LAYOUT-1a: the header's block has its first baseline on the title's
  // first baseline, whatever their sizes; so, in tier XL, does the label of
  // the contents at the window's edge.
  const headerItems = headers.map((m) => {
    const r = rect(m);
    const title = m.closest(".essay-header")?.querySelector("h1, .essay-title");
    const dy = title ? firstBaseline(title) - firstBaseline(m) : 0;
    return { els: [m], top: r.top + dy, h: r.height, fixed: true, header: true, natural: r.top };
  });
  alignContents();
  const items = [
    ...stubs.map((s) => ({ els: [s], top: rect(s).top, h: rect(s).height, fixed: false })),
    ...exhibits.map((els) => { const [t, b] = extent(els); return { els, top: t, h: b - t, fixed: true }; }),
    ...headerItems,
  ].sort((a, b) => a.top - b.top);
  for (const it of items) if (it.natural === undefined) it.natural = it.top;
  const openStubs = [marginOpen?.stub, marginPreview?.stub].filter(Boolean);
  const lineOf = (i) => parseFloat(getComputedStyle(i).lineHeight);
  const gap = stubs.length ? lineOf(stubs[0]) * 0.25 : 4;
  const clear = (y, h, zones) => {
    for (let moved = true; moved;) {
      moved = false;
      for (const [top, bottom] of zones) if (y < bottom + gap && y + h > top - gap) { y = bottom + gap; moved = true; }
    }
    return y;
  };
  // Pass 1, everything collapsed: the header's block where it belongs; other
  // fixed items (figure words) where they belong unless the
  // header's block is there, in which case below it; stubs after the one
  // above, clear of every fixed item.
  const headerZones = headerItems.map((i) => [i.top, i.top + i.h]);
  for (const it of items) if (it.fixed) it.y = it.header ? it.top : clear(it.top, it.h, headerZones);
  const fixedZones = items.filter((i) => i.fixed).map((i) => [i.y, i.y + i.h]);
  let last = -Infinity;
  for (const it of items) {
    const h = openStubs.includes(it.els[0]) ? lineOf(it.els[0]) : it.h;
    if (it.fixed) { last = Math.max(last, it.y + h); continue; }
    it.y = clear(Math.max(it.top, last + gap), h, fixedZones);
    last = it.y + h;
  }
  // Pass 2: an open item (pinned or previewed) keeps its place and grows;
  // what is below it moves down, each open item in turn.
  for (const o of items.filter((i) => openStubs.includes(i.els[0])).sort((a, b) => a.y - b.y)) {
    let bottom = o.y + o.h;
    for (const it of items.filter((i) => i !== o && i.y >= o.y).sort((a, b) => a.y - b.y)) {
      it.y = Math.max(it.y, bottom + gap);
      bottom = it.y + it.h;
    }
  }
  for (const it of items) {
    const dy = it.y - it.natural;
    if (Math.abs(dy) > 0.5) for (const e of it.els) e.style.transform = `translateY(${dy}px)`;
  }
}

let layoutFrame = 0;
let refreshToc = () => {};   // set by setupBar
function scheduleLayout() {
  cancelAnimationFrame(layoutFrame);
  layoutFrame = requestAnimationFrame(() => {
    const t = tier();
    if (t !== currentTier) { setupMargin(); currentTier = t; }
    positionMargin();
    placeBar();
    refreshToc();
    repin?.();
    // an open popup follows its circle (after a size step or a resize)
    if (open && open.mode === "float" && open.trigger.isConnected) {
      open.box.style.maxHeight = "";
      placeFloat(open.box, open.trigger);
    }
  });
}

// ── Reading bar (BAR-1) ──────────────────────────────────────────────────

const bar = byId("bar");
const barTitle = bar?.querySelector(".bar-title");
let headerVisible = true, lastY = scrollY, idle = 0;

function showBar() { bar.classList.add("is-shown"); restartIdle(); }

// BAR-1d: as wide as the text block (both margins and the column in tiers
// L and XL, the column alone in M and S), so it never covers the contents
// in XL; its contents start at the column's left edge and end at its right.
// The bar is fixed to the viewport, so this is measured: CSS cannot know
// where the text block landed.
function placeBar() {
  if (!bar || !article) return;
  const a = article.getBoundingClientRect();
  const cs = getComputedStyle(article);
  let colL, colR, blockL, blockR;
  if (wide()) {
    const fs = parseFloat(cs.fontSize);
    const v = (name) => parseFloat(getComputedStyle(page).getPropertyValue(name)) * fs;
    colL = a.left;
    colR = colL + v("--measure");
    blockL = colL - v("--margin-gap") - parseFloat(cs.getPropertyValue("--left-margin"));
    blockR = colR + v("--margin-gap") + parseFloat(cs.getPropertyValue("--margin"));
  } else {
    blockL = colL = a.left + parseFloat(cs.paddingLeft);
    blockR = colR = a.right - parseFloat(cs.paddingRight);
  }
  Object.assign(bar.style, {
    left: `${blockL}px`, right: "auto", width: `${blockR - blockL}px`,
    paddingLeft: `${colL - blockL}px`, paddingRight: `${blockR - colR}px`,
  });
}
function hideBar() { if (!keepBar()) bar.classList.remove("is-shown"); }
function keepBar() {
  return bar.matches(":hover") || bar.contains(document.activeElement) || (open && open.mode === "toc");
}
function restartIdle() { clearTimeout(idle); idle = setTimeout(hideBar, 2000); }

function sectionTitle(s) {
  if (s.dataset.short) return s.dataset.short;
  const h = s.querySelector(":scope > h2");
  return h ? h.textContent.replace(/§\s*$/, "").trim() : "";
}
const essayTitle = document.querySelector(".essay-header h1")?.textContent.trim() || document.title;

function setupBar() {
  if (!bar) return;
  bar.hidden = false;
  const header = document.querySelector(".site-header");
  new IntersectionObserver(([e]) => {
    headerVisible = e.isIntersecting;
    if (headerVisible) bar.classList.remove("is-shown");
  }).observe(header);
  // BAR-1b: direction and an idle timer, nothing else
  addEventListener("scroll", () => {
    const y = scrollY;
    if (y < lastY - 2 && !headerVisible) showBar();
    else if (y > lastY + 2 && performance.now() - placeKeptAt > 500) hideBar();
    lastY = y;
    if (bar.classList.contains("is-shown")) restartIdle();
  }, { passive: true });
  bar.addEventListener("pointerleave", restartIdle);
  bar.addEventListener("focusin", showBar);      // BAR-1a: tabbing in reveals it
  bar.addEventListener("focusout", restartIdle);

  // The current section, by IntersectionObserver (BAR-1b): the top level
  // for the bar; both levels for the contents in the margin (TOC-2).
  const sections = [...document.querySelectorAll("article section.level-1")];
  const subsections = [...document.querySelectorAll("article section.level-1 > section.level-2")];
  const tocLinks = [...document.querySelectorAll("nav.toc a[href^='#']")];
  const tocList = document.querySelector("nav.toc .toc-inner > ul");
  const tocMark = tocList && el("span", { class: "toc-mark", "aria-hidden": "true", hidden: "" });
  if (tocMark) tocList.append(tocMark);
  let shownTop = null;
  const inBand = new Set();
  const currentOf = (list) => {
    for (const s of list) if (inBand.has(s)) return s;
    // above the band: the last section that started above the viewport
    const passed = list.filter((s) => s.getBoundingClientRect().top < innerHeight * 0.3);
    return passed[passed.length - 1] || null;
  };
  const update = () => {
    const current = currentOf(sections);
    barTitle.textContent = current ? sectionTitle(current) : essayTitle;
    bar.dataset.current = current ? current.id : "";
    const sub = current && currentOf(subsections.filter((s) => s.parentElement === current));
    const ids = new Set([current?.id, sub?.id].filter(Boolean).map((id) => `#${id}`));
    for (const a of tocLinks) {
      if (ids.has(a.getAttribute("href"))) a.setAttribute("aria-current", "location");
      else a.removeAttribute("aria-current");
    }
    // TOC-2: a hairline in the gutter beside the deepest current entry
    if (tocMark) {
      const deepest = tocList.querySelector(`a[href="#${(sub || current)?.id}"]`);
      tocMark.hidden = !deepest;
      if (deepest) {
        const r = deepest.getBoundingClientRect(), u = tocList.getBoundingClientRect();
        tocMark.style.top = `${r.top - u.top + tocList.scrollTop + (r.height - tocMark.offsetHeight) / 2}px`;
        tocMark.style.left = `${r.left - u.left - 0.55 * parseFloat(getComputedStyle(deepest).fontSize)}px`;
      }
    }
    // TOC-2: a list too tall for the window scrolls itself, keeping the
    // current section at its top (what is left to read, below it)
    if (current && current.id !== shownTop) {
      shownTop = current.id;
      const li = tocList?.querySelector(`:scope > li > a[href="#${current.id}"]`)?.parentElement;
      if (li && tocList.scrollHeight > tocList.clientHeight) {
        tocList.scrollTo({ top: li.offsetTop, behavior: reducedMotion.matches ? "auto" : "smooth" });
      }
    }
  };
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) e.isIntersecting ? inBand.add(e.target) : inBand.delete(e.target);
    update();
  }, { rootMargin: "0px 0px -70% 0px" });
  [...sections, ...subsections].forEach((s) => io.observe(s));
  refreshToc = update;
  update();
}

// TOC-2: a truncated entry in the margin contents shows in full on hover
// or focus, over the gap, without moving anything.
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
function setupTocTitles() {
  const toc = document.querySelector("nav.toc");
  if (!toc) return;
  let tip = null;
  const hide = () => { tip?.remove(); tip = null; };
  const show = (e) => {
    const a = e.target.closest?.("a");
    hide();
    if (!a || a.scrollWidth <= a.clientWidth) return;
    const r = a.getBoundingClientRect();
    const cs = getComputedStyle(a);
    tip = el("div", { class: "toc-full", "aria-hidden": "true" }, a.textContent);
    Object.assign(tip.style, { left: `${r.left}px`, top: `${r.top - 1}px`, font: cs.font, lineHeight: `${r.height}px` });
    document.body.append(tip);
  };
  toc.addEventListener("pointerover", show);
  toc.addEventListener("focusin", show);
  toc.addEventListener("pointerleave", hide);
  toc.addEventListener("focusout", hide);
  toc.querySelector(".toc-inner > ul")?.addEventListener("scroll", hide, { passive: true });
  addEventListener("scroll", hide, { passive: true });
}

// The full contents, from the bar, with the current section marked.
function tocContent() {
  const toc = document.querySelector("nav.toc");
  let list;
  if (toc) list = clean(toc.querySelector("ul"));
  else {
    list = el("ul");
    for (const s of document.querySelectorAll("article section.level-1")) {
      list.append(el("li", {}, el("a", { href: `#${s.id}` }, sectionTitle(s))));
    }
  }
  const current = bar.dataset.current;
  for (const a of list.querySelectorAll("a")) {
    if (current && a.getAttribute("href") === `#${current}`) a.setAttribute("aria-current", "location");
    else a.removeAttribute("aria-current");
  }
  list.classList.add("toc-list");
  return { title: essayTitle, body: el("nav", { "aria-label": "Contents" }, list) };
}

function toggleToc() {
  const button = bar.querySelector(".bar-section");
  if (open && open.mode === "toc") { close(); return; }
  close();
  const box = buildPopup(tocContent(), true);
  box.classList.add("toc-popup");
  let shade = null;
  if (touch.matches) shade = placePopin(box);
  else {
    mount().append(box);
    const r = button.getBoundingClientRect();
    box.style.position = "fixed";
    box.style.left = `${Math.max(8, r.left)}px`;
    if (r.top > innerHeight / 2) {       // the bar is at the bottom: open upwards
      box.style.bottom = `${innerHeight - r.top + 6}px`;
      box.style.maxHeight = `${r.top - 20}px`;
    } else {
      box.style.top = `${r.bottom + 6}px`;
      box.style.maxHeight = `${innerHeight - r.bottom - 20}px`;
    }
  }
  open = { box, trigger: button, pinned: true, mode: shade ? "popin" : "toc", shade };
  if (shade) open.mode = "popin";
  bar.classList.add("toc-open", "is-shown");
  button.setAttribute("aria-expanded", "true");
  box.querySelector("[aria-current]")?.focus({ preventScroll: true }) || box.focus();
}

// ── Site menu (NAV-1) ─────────────────────────────────────────────────────
// A <details> element, so it opens without scripts; here it also closes on
// a click elsewhere and on Escape.

const menu = document.querySelector(".site-menu");
if (menu) {
  document.addEventListener("click", (e) => {
    if (menu.open && !menu.contains(e.target)) menu.open = false;
  });
  menu.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && menu.open) {
      menu.open = false;
      menu.querySelector("summary").focus();
      e.stopPropagation();
    }
  });
}

// ── Start ────────────────────────────────────────────────────────────────

showTheme();
showSize();
setupBar();
setupTocTitles();
setupExhibits();
scheduleLayout();
document.fonts?.ready.then(scheduleLayout);
new ResizeObserver(scheduleLayout).observe(page);
// The text block can move while the page keeps its width: Firefox first
// lays out tier XL as if the contents' column were not reserved, then
// corrects it, so the article is watched too, and the page's load ends a
// last pass (BAR-1d, LAYOUT-1a).
if (article) new ResizeObserver(scheduleLayout).observe(article, { box: "border-box" });   // the column keeps its width; the margins change
addEventListener("load", scheduleLayout);

// TABLE-4/5: the table script loads only on pages that need it.
if (document.querySelector("table[data-sortable], .table-wrap table tbody tr:nth-child(15)")) {
  const src = document.querySelector("script[data-tables]")?.dataset.tables;
  if (src) import(src).catch(() => {});
}
