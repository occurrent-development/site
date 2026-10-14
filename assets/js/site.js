// occurrentdevelopment.com — the interactive layer. IDs refer to SPEC.md.
//
// A deferred module that runs after first paint (PERF-1). Everything it
// enhances is already in the HTML and works without it: circles and links
// lead to the end matter, margin notes run in, asides are listed at the end.

const root = document.documentElement;
const page = document.querySelector(".page");
const article = document.querySelector("article");
const canHover = matchMedia("(hover: hover) and (pointer: fine)");

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

function setSize(n) {
  n = Math.max(0, Math.min(SIZES - 1, n));
  if (n === MID) delete root.dataset.size; else root.dataset.size = String(n);
  store.set("size", n === MID ? null : String(n));
  showSize();
  close();
  scheduleLayout();
}

addEventListener("storage", (e) => {
  if (e.key === "theme") {
    if (e.newValue) root.dataset.theme = e.newValue; else delete root.dataset.theme;
    showTheme();
  }
  if (e.key === "size") {
    if (e.newValue) root.dataset.size = e.newValue; else delete root.dataset.size;
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
  for (const e of c.querySelectorAll(".back, .self, .aside[hidden]")) e.remove();
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
    // A full note is already the reference; a short one gets the entry (POP-7).
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
  const h = c.querySelector(":scope > h2, :scope > h3, :scope > h4");
  const title = h ? h.textContent.replace(/§\s*$/, "").trim() : "";
  if (h) h.remove();
  for (const x of c.querySelectorAll(".circle-link, .circle")) x.remove();
  return { title, body: el("div", {}, ...c.childNodes) };
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

const TRIGGERS = ".circle-link, a.term[data-targets], a.link.same, a.link.xref, a.link.ext";
function kindOf(t) {
  if (t.matches(".circle-link, a.term[data-targets]")) return "circle";
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

// ── The open item: a popup, a popin, a margin panel or an expanded stub ────

let open = null;      // { box, trigger, pinned, mode, shade }
let openTimer = 0, closeTimer = 0, seq = 0;

function buildPopup(c, pinned) {
  const id = `popup-title-${++seq}`;
  const box = el("div", { class: "popup", role: pinned ? "dialog" : "tooltip", "aria-labelledby": id, tabindex: "-1" });
  const bar = el("div", { class: "popup-bar" },
    el("span", { class: "popup-title", id }, c.title || ""),
    c.url ? el("a", { class: "popup-open", href: c.url, target: "_blank", rel: "noopener" }, "Open in new tab") : null,
    el("button", { type: "button", class: "popup-close", "aria-label": "Close" }, "×"));
  box.append(bar, el("div", { class: "popup-body" }, c.body));
  return box;
}

// POP-2: in the viewport, never over the element that opened it.
function placeFloat(box, t) {
  document.body.append(box);
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
  document.body.append(shade, box);
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
  close();
  const kind = kindOf(t);
  const targets = (t.dataset.targets || "").split(" ");
  // POP-8: on wide tiers circles open in the margin; an aside expands its stub.
  if (kind === "circle" && tier() === "L") {
    if (targets.length === 1 && targets[0].startsWith("aside-")) {
      const stub = byId("aside-text-" + targets[0].slice(6));
      if (stub && stub.classList.contains("stub")) { expandStub(stub, t, pinned, focus); return; }
    }
    openMarginPanel(t, pinned, focus);
    return;
  }
  const c = await contentFor(t);
  if (!c || (open && open.trigger === t)) return;
  close();
  const box = buildPopup(c, pinned);
  let shade = null, mode = "float";
  if (!canHover.matches) { shade = placePopin(box); mode = "popin"; pinned = true; box.setAttribute("role", "dialog"); }
  else placeFloat(box, t);
  open = { box, trigger: t, pinned, mode, shade };
  t.setAttribute("aria-expanded", "true");
  if (focus || mode === "popin") box.focus({ preventScroll: true });
}

function openMarginPanel(t, pinned, focus) {
  const c = circleContent(t);
  if (!c.items.length) return;
  const box = el("span", { class: "in-margin margin-panel", role: pinned ? "dialog" : "tooltip", tabindex: "-1",
                           "aria-label": c.title });
  if (c.items.length === 1 && c.items[0].head) box.append(el("span", { class: "popup-item-head", style: "display:block" }, c.items[0].head));
  box.append(c.body);
  (t.closest(".nw") || t).after(box);
  open = { box, trigger: t, pinned, mode: "margin" };
  t.setAttribute("aria-expanded", "true");
  t.querySelector(".circle")?.classList.add("is-open");
  if (focus) box.focus({ preventScroll: true });
}

// ASIDE-3: one expanded at a time, drawn over what is below; nothing moves.
function expandStub(stub, trigger, pinned, focus) {
  if (stub.dataset.full) { if (focus) stub.focus(); return; }
  stub.classList.add("is-open");
  stub.setAttribute("aria-expanded", "true");
  open = { box: stub, trigger: trigger || circleFor(stub) || stub, pinned, mode: "stub" };
  open.trigger.setAttribute?.("aria-expanded", "true");
  if (focus) stub.focus({ preventScroll: true });
}

function pin() {
  if (!open) return;
  open.pinned = true;
  if (open.mode !== "stub") open.box.setAttribute("role", "dialog");
}

function close({ returnFocus = false } = {}) {
  clearTimeout(openTimer);
  clearTimeout(closeTimer);
  if (!open) return;
  const o = open;
  open = null;
  if (o.mode === "stub") {
    o.box.classList.remove("is-open");
    o.box.setAttribute("aria-expanded", "false");
    restoreReplaced(o.box);
  } else {
    o.box.remove();
  }
  o.shade?.remove();
  if (o.mode === "popin") root.style.overflow = "";
  o.trigger.setAttribute?.("aria-expanded", "false");
  o.trigger.querySelector?.(".circle")?.classList.remove("is-open");
  if (o.mode === "toc") bar?.classList.remove("toc-open");
  if (returnFocus) o.trigger.focus?.();
}

function scheduleClose() {
  clearTimeout(closeTimer);
  if (open && !open.pinned) closeTimer = setTimeout(close, 250);
}

// POP-6, TERM-7: a circle inside an open item replaces its content, with Back.
function replaceContent(box, t) {
  const body = box.querySelector(".popup-body") || box;
  const c = circleContent(t);
  if (!c.items.length) return;
  const saved = [...body.childNodes];
  const back = el("button", { type: "button", class: "popup-back" }, "← Back");
  back.addEventListener("click", (e) => {
    e.stopPropagation();
    body.replaceChildren(...saved);
  });
  if (!box._original) box._original = saved;
  body.replaceChildren(el("p", {}, back), ...(c.items.length === 1 && c.items[0].head ? [el("p", { class: "popup-item-head" }, c.items[0].head)] : []), c.body);
  const title = box.querySelector(".popup-title");
  if (title) title.textContent = c.title;
}
function restoreReplaced(box) {
  if (box._original) { box.replaceChildren(...box._original); delete box._original; }
}

// ── Events ────────────────────────────────────────────────────────────────

const OPENED = ".popup, .margin-panel, .stub.is-open";

document.addEventListener("click", (e) => {
  const t = e.target.closest(TRIGGERS);
  const inOpen = e.target.closest(OPENED);

  if (e.target.closest("[data-theme-toggle]")) { setTheme(THEMES[(THEMES.indexOf(theme()) + 1) % 3]); return; }
  if (e.target.closest(".size-down")) { setSize(size() - 1); return; }
  if (e.target.closest(".size-up")) { setSize(size() + 1); return; }
  if (e.target.closest(".popup-close")) { close({ returnFocus: true }); return; }
  if (e.target.closest(".bar-section")) { e.preventDefault(); toggleToc(); return; }

  if (t) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return; // LINK-3: native tabs
    if (inOpen && kindOf(t) === "circle") { e.preventDefault(); replaceContent(inOpen, t); return; }
    if (inOpen) { close(); return; }   // other links inside a popup simply navigate
    e.preventDefault();
    if (open && open.trigger === t && open.pinned) { close(); return; }
    openFor(t, { pinned: true, focus: e.detail === 0 });
    return;
  }

  const stub = e.target.closest(".stub");
  if (stub) {
    if (open && open.box === stub) { close(); return; }
    close();
    expandStub(stub, null, true, false);
    return;
  }

  // A contents link in the bar's popup: let it navigate (BAR-2), then close.
  if (open && open.mode === "toc" && e.target.closest(".popup a[href^='#']")) { close(); return; }
  if (open && !inOpen && !e.target.closest(".bar")) close();
});

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && open) { close({ returnFocus: true }); return; }
  const stub = e.target.closest?.(".stub");
  if (stub && (e.key === "Enter" || e.key === " ")) {
    e.preventDefault();
    if (open && open.box === stub) close({ returnFocus: false });
    else { close(); expandStub(stub, null, true, false); }
  }
});

// Hover: open after ~300 ms, close ~250 ms after leaving both (§11 table).
document.addEventListener("pointerover", (e) => {
  if (e.pointerType !== "mouse" || !canHover.matches) return;
  const t = e.target.closest(TRIGGERS);
  if (t && !t.closest(OPENED + ", .bar")) {
    if (kindOf(t) === "xref") fetchFragment(t.getAttribute("href"));   // prefetch
    highlight(t, true);
    clearTimeout(closeTimer);
    if (open && open.trigger === t) return;
    clearTimeout(openTimer);
    openTimer = setTimeout(() => { if (!(open && open.pinned)) openFor(t); }, 300);
    return;
  }
  const stub = e.target.closest(".stub");
  if (stub) highlight(circleFor(stub), true, stub);
  if (e.target.closest(OPENED)) clearTimeout(closeTimer);
});

document.addEventListener("pointerout", (e) => {
  if (e.pointerType !== "mouse") return;
  const from = e.target.closest(TRIGGERS + ", " + OPENED + ", .stub");
  if (!from) return;
  const to = e.relatedTarget?.closest?.(TRIGGERS + ", " + OPENED + ", .stub");
  if (to === from) return;
  if (from.matches(TRIGGERS)) highlight(from, false);
  if (from.matches(".stub")) highlight(circleFor(from), false, from);
  clearTimeout(openTimer);
  if (open && to && (to === open.trigger || to === open.box)) return;
  scheduleClose();
});

// ASIDE-2: an aside's circle and its stub take the accent together.
function circleFor(stub) {
  const id = "aside-" + stub.id.replace("aside-text-", "");
  return [...document.querySelectorAll(".circle-link")].find((c) => c.dataset.targets.split(" ").includes(id)) || null;
}
function highlight(trigger, on, stub) {
  if (!trigger) return;
  const s = stub || (trigger.dataset.targets || "").split(" ").filter((x) => x.startsWith("aside-"))
    .map((x) => byId("aside-text-" + x.slice(6))).find((x) => x && x.classList.contains("stub"));
  trigger.classList.toggle("hl", on);
  s?.classList.toggle("hl", on);
}

// ── The margin, tier L (POP-8, ASIDE-3/4, MNOTE-2/4, IMG-2) ────────────────

let currentTier = null;

function setupMargin() {
  const L = tier() === "L";
  if (L === (currentTier === "L") && currentTier !== null) return;
  close();
  for (const a of article?.querySelectorAll(".aside[id^='aside-text-']") || []) {
    if (a.closest("#asides")) continue;
    if (L) {
      a.hidden = false;
      a.classList.add("in-margin", "stub");
      a.tabIndex = 0;
      a.setAttribute("role", "button");
      a.setAttribute("aria-expanded", "false");
    } else {
      a.hidden = true;
      a.classList.remove("in-margin", "stub", "is-full", "is-open", "hl");
      a.removeAttribute("tabindex");
      a.removeAttribute("role");
      a.removeAttribute("aria-expanded");
      delete a.dataset.full;
      a.style.transform = "";
    }
  }
  for (const m of article?.querySelectorAll(".margin-note") || []) {
    m.classList.toggle("in-margin", L);
    if (!L) m.style.transform = "";
  }
}

function positionMargin() {
  if (tier() !== "L" || !article) return;
  const items = [...article.querySelectorAll(".in-margin.stub, .in-margin.margin-note")];
  for (const it of items) it.style.transform = "";
  // ASIDE-3: an aside that fits in two margin lines is shown in full
  for (const s of items.filter((i) => i.classList.contains("stub"))) {
    s.classList.add("is-full");
    const lh = parseFloat(getComputedStyle(s).lineHeight);
    if (s.offsetHeight <= 2 * lh + 1) s.dataset.full = "1";
    else { delete s.dataset.full; s.classList.remove("is-full"); }
  }
  const rect = (x) => x.getBoundingClientRect();
  // MNOTE-4: margin notes hold their place; IMG-2: wide and full elements take the margin
  const blocked = [
    ...items.filter((i) => i.classList.contains("margin-note")).map((n) => [rect(n).top, rect(n).bottom]),
    ...[...article.querySelectorAll(".w-wide, .w-full")].map((o) => [rect(o).top, rect(o).bottom]),
  ];
  let last = -Infinity;
  for (const it of items) {
    const r = rect(it);
    if (it.classList.contains("margin-note")) { last = Math.max(last, r.bottom); continue; }
    let y = Math.max(r.top, last + 4);
    // ASIDE-4: move down just enough to clear what is already there
    for (let moved = true; moved;) {
      moved = false;
      for (const [top, bottom] of blocked) {
        if (y < bottom + 4 && y + r.height > top - 4) { y = bottom + 4; moved = true; }
      }
    }
    if (y !== r.top) it.style.transform = `translateY(${y - r.top}px)`;
    last = y + r.height;
  }
}

let layoutFrame = 0;
function scheduleLayout() {
  cancelAnimationFrame(layoutFrame);
  layoutFrame = requestAnimationFrame(() => {
    const t = tier();
    if (t !== currentTier) { setupMargin(); currentTier = t; }
    positionMargin();
  });
}

// ── Reading bar (BAR-1) ──────────────────────────────────────────────────

const bar = byId("bar");
const barTitle = bar?.querySelector(".bar-title");
let headerVisible = true, lastY = scrollY, idle = 0;

function showBar() { bar.classList.add("is-shown"); restartIdle(); }
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
    lastY = y;
    if (bar.classList.contains("is-shown")) restartIdle();
  }, { passive: true });
  bar.addEventListener("pointerleave", restartIdle);
  bar.addEventListener("focusin", showBar);      // BAR-1a: tabbing in reveals it
  bar.addEventListener("focusout", restartIdle);

  // The current top-level section, by IntersectionObserver (BAR-1b)
  const sections = [...document.querySelectorAll("article section.level-1")];
  const inBand = new Set();
  const update = () => {
    let current = null;
    for (const s of sections) if (inBand.has(s)) { current = s; break; }
    if (!current) {
      // above the band: the last section that started above the viewport
      const passed = sections.filter((s) => s.getBoundingClientRect().top < innerHeight * 0.3);
      current = passed[passed.length - 1] || null;
    }
    barTitle.textContent = current ? sectionTitle(current) : essayTitle;
    bar.dataset.current = current ? current.id : "";
  };
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) e.isIntersecting ? inBand.add(e.target) : inBand.delete(e.target);
    update();
  }, { rootMargin: "0px 0px -70% 0px" });
  sections.forEach((s) => io.observe(s));
  update();
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
  if (!canHover.matches) shade = placePopin(box);
  else {
    document.body.append(box);
    const r = button.getBoundingClientRect();
    box.style.position = "fixed";
    box.style.left = `${Math.max(8, r.left)}px`;
    box.style.top = `${r.bottom + 6}px`;
    box.style.maxHeight = `${innerHeight - r.bottom - 20}px`;
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
scheduleLayout();
document.fonts?.ready.then(scheduleLayout);
new ResizeObserver(scheduleLayout).observe(page);

// TABLE-4/5: the table script loads only on pages that need it.
if (document.querySelector("table[data-sortable], .table-wrap table tbody tr:nth-child(15)")) {
  const src = document.querySelector("script[data-tables]")?.dataset.tables;
  if (src) import(src).catch(() => {});
}
