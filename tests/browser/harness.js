// Browser tests and screenshot scenarios for the interactive layer. IDs refer
// to SPEC.md. Run by tools/browser_test.py in headless Chrome, which serves
// this folder at /__test/ beside the built site, so the frame is same-origin
// and the harness can reach into it.
//
//   harness.html?run=tests              run the tests; results are posted to /__results
//   harness.html?show=<scenario>&theme=  set up a scenario for a screenshot

const frame = document.getElementById("page");
const params = new URLSearchParams(location.search);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let w, d;

async function load(path = "/specimen", width, height) {
  if (width) { frame.style.width = `${width}px`; frame.style.height = `${height}px`; }
  await new Promise((r) => { frame.onload = r; frame.src = path; });
  w = frame.contentWindow; d = w.document;
  await d.fonts?.ready;
  await settle();
}
async function settle(ms = 400) {
  await new Promise((r) => w.requestAnimationFrame(() => w.requestAnimationFrame(r)));
  await sleep(ms);
}
async function resize(width, height) {
  frame.style.width = `${width}px`;
  frame.style.height = `${height}px`;
  await settle(500);
}
async function scroll(y) { w.scrollTo({ top: y, behavior: "instant" }); await settle(); }

const tier = () => w.getComputedStyle(d.querySelector("article")).getPropertyValue("--tier").trim();
const rect = (x) => x.getBoundingClientRect();
const pinned = () => [...d.querySelectorAll(".popup.is-pinned")];
const titles = (boxes) => boxes.map((b) => b.querySelector(".popup-title").textContent);
// A trigger in the text (not in the end matter, an aside, the contents or a popup).
const trig = (target) => [...d.querySelectorAll("article .circle-link, article a.term[data-targets], article a.aside-phrase[data-targets]")]
  .find((a) => a.dataset.targets === target && !a.closest(".endmatter, .aside, nav, .popup"));
const key = (k, on = d.activeElement || d.body) =>
  on.dispatchEvent(new w.KeyboardEvent("keydown", { key: k, bubbles: true, cancelable: true }));
const pointer = (type, on, x, y) =>
  on.dispatchEvent(new w.PointerEvent(type, { bubbles: true, cancelable: true, pointerType: "mouse", clientX: x, clientY: y, button: 0, pointerId: 1 }));
async function closeAll() {
  for (const b of [...d.querySelectorAll(".popup")]) b.querySelector(".popup-close")?.click();
  await settle(100);
}

// The baseline of an element's first line, measured as the site does.
function baseline(e) {
  const walk = d.createTreeWalker(e, w.NodeFilter.SHOW_TEXT);
  let n;
  while ((n = walk.nextNode()) && !n.data.trim());
  if (!n) return rect(e).top;
  const probe = d.createElement("span");
  probe.style.cssText = "display:inline-block;width:0;height:0;vertical-align:baseline";
  n.before(probe);
  const y = rect(probe).top;
  probe.remove();
  return y;
}

// ── Tests ────────────────────────────────────────────────────────────────

const results = [];
async function test(name, fn) {
  try { await fn(); results.push({ name, ok: true }); }
  catch (e) { results.push({ name, ok: false, detail: String(e?.message || e) }); }
  try { await closeAll(); } catch (e) { /* the next test reloads */ }
}
function expect(ok, msg) { if (!ok) throw new Error(msg); }
const near = (a, b, tol, what) => expect(Math.abs(a - b) <= tol, `${what}: ${a.toFixed(1)} vs ${b.toFixed(1)}`);

async function tests() {
  await load("/specimen", 2560, 1440);
  const em = () => parseFloat(w.getComputedStyle(d.querySelector("article")).fontSize);
  const v = (name) => parseFloat(w.getComputedStyle(d.querySelector(".page")).getPropertyValue(name)) * em();
  const cssLen = (name) => parseFloat(w.getComputedStyle(d.querySelector("article")).getPropertyValue(name));

  await test("The browser has a pointer that hovers (the rest assume one)", async () => {
    expect(w.matchMedia("(hover: hover)").matches, "the page sees (hover: none) and takes the touch path; see POINTER in browser_test.py");
  });

  await test("BRAND-2: the page links the SVG icon, favicon.ico and the touch icon, and each is served", async () => {
    const want = [["icon", "/assets/brand/logo.svg"], ["icon", "/favicon.ico"], ["apple-touch-icon", "/assets/brand/apple-touch-icon.png"]];
    for (const [rel, href] of want) {
      const link = d.querySelector(`link[rel="${rel}"][href="${href}"]`);
      expect(link, `no <link rel="${rel}" href="${href}">`);
      const r = await w.fetch(href);
      expect(r.ok && (await r.blob()).size > 0, `${href}: ${r.status}`);
    }
    expect(d.querySelector('link[href="/assets/brand/logo.svg"]').type === "image/svg+xml", "the SVG icon has no type");
  });

  await test("Every page is laid out as the specimen at 2,560 px: menu, column, text, margins", async () => {
    const geometry = () => {
      const r = (sel) => { const e = d.querySelector(sel); return e ? Math.round(rect(e).left) : null; };
      return { tier: tier(), menu: r(".menu-rail .site-menu"), column: r("article > .toc, article .toc"),
               text: r("article"), menuTop: Math.round(rect(d.querySelector(".menu-rail .site-menu")).top) };
    };
    const want = geometry();
    for (const path of ["/", "/essays", "/blog", "/correspondence", "/placeholder"]) {
      await load(path);
      const got = geometry();
      for (const k of Object.keys(want)) expect(got[k] === want[k], `${path}: ${k} ${got[k]}, the specimen's ${want[k]}`);
    }
    await load("/specimen");
  });

  await test("LAYOUT-6a, TOC-2: at 2,560 px the contents, margins and column are one centred block, no gap", async () => {
    expect(tier() === "XL", `tier ${tier()}`);
    const a = rect(d.querySelector("article")), toc = rect(d.querySelector("nav.toc"));
    const gap = v("--margin-gap"), lm = cssLen("--left-margin"), rm = cssLen("--margin");
    near(toc.right + gap, a.left - gap - lm, 1, "contents' right edge + gap vs left margin's left edge");
    const leftSpace = toc.left, rightSpace = d.documentElement.clientWidth - (a.left + v("--measure") + gap + rm);
    near(leftSpace, rightSpace, 2, "space left vs right of the block");
  });

  // LAYOUT-1a (2026-11-03): the datum is the abstract's first line when there is one, else the first
  // line after the title and subtitle (the first element after the header that carries text)
  const datumOf = (h) => {
    const abs = h.querySelector(".abstract");
    if (abs) return baseline(abs);
    let next = h.nextElementSibling;
    while (next && (next.matches(".toc, .dock, hr, script, style") || !next.textContent.trim())) next = next.nextElementSibling;
    return baseline(next);
  };
  await test("LAYOUT-1a: the Contents heading and the block's first line sit on the datum (the abstract's first line), in both themes, samples too", async () => {
    for (const theme of ["light", "dark"]) {
      d.documentElement.dataset.theme = theme;
      await settle(300);
      const header = d.querySelector(".essay-header:not(.sample)");
      expect(header.querySelector(".abstract"), "the specimen has no abstract: the test assumes one");
      const datum = datumOf(header);
      const sub = baseline(header.querySelector(".subtitle"));
      expect(datum > sub + 10, `${theme}: the datum (${datum}) is not below the subtitle (${sub})`);
      const block = header.querySelector(".header-meta");
      // the specimen is a page: no author line (LAYOUT-1e), so its block opens with Published
      expect(/^Published:/.test(block.firstElementChild.textContent.trim()), `${theme}: the block opens with ${block.firstElementChild.textContent}`);
      near(baseline(d.querySelector("nav.toc .toc-title")), datum, 1.5, `${theme}: Contents`);
      near(baseline(block), datum, 1.5, `${theme}: the block`);
      // the specimen's samples: the same rule
      for (const h of d.querySelectorAll(".essay-header.sample")) {
        const title = h.querySelector("h1, .essay-title");
        const want = datumOf(h);
        const meta = h.querySelector(".header-meta");
        expect(/^Author:/.test(meta.firstElementChild.textContent.trim()), `${theme}: a sample's block opens with ${meta.firstElementChild.textContent}`);
        near(baseline(meta), want, 1.5, `${theme}: sample "${title.textContent.slice(0, 20)}", its Author line`);
      }
    }
    delete d.documentElement.dataset.theme;
    await settle(200);
  });

  await test("LAYOUT-1b, 1d, 1e: Author:, Published: and Edited: on every post; a never-edited post shows the same date twice", async () => {
    const lines = (h) => [...h.querySelectorAll(".header-meta .meta-label")].map((l) => l.textContent.trim());
    const main = d.querySelector(".essay-header:not(.sample)");
    expect(lines(main).join(" ") === "Published: Edited: Tagged:", `specimen (a page): ${lines(main)}`);
    const sample = d.querySelector(".essay-header.sample");
    expect(lines(sample).join(" ") === "Author: Published: Edited: Tagged:", `the essay sample: ${lines(sample)}`);
    const entry = [...d.querySelectorAll(".essay-header.sample")].find((h) => /Guest/.test(h.textContent));
    expect(entry, "no guest sample");
    expect(/Author:\s*A Guest/.test(entry.querySelector(".author").textContent), "the guest's name");
    const dates = [...entry.querySelectorAll(".date")].map((x) => x.textContent.replace(/^\S+\s*/, "").trim());
    expect(dates.length === 2 && dates[0] === dates[1], `the entry's dates: ${dates}`);
  });

  await test("BRAND-3: the manifest is linked and served, with the head metas", async () => {
    const link = d.querySelector('link[rel="manifest"]');
    expect(link?.getAttribute("href") === "/assets/brand/site.webmanifest", "no manifest link");
    const m = await (await w.fetch(link.getAttribute("href"))).json();
    expect(m.name === "Occurrent Development" && m.short_name === "Occ Dev" && m.display === "standalone"
      && m.start_url === "/" && m.scope === "/", `manifest: ${JSON.stringify(m)}`);
    for (const ic of m.icons) {
      const r = await w.fetch(ic.src);
      expect(r.ok, `${ic.src}: ${r.status}`);
    }
    expect(d.querySelector('meta[name="apple-mobile-web-app-title"]')?.content === "Occ Dev", "no apple-mobile-web-app-title");
    const tc = [...d.querySelectorAll('meta[name="theme-color"]')].map((x) => `${x.media} ${x.content}`);
    expect(tc.includes("(prefers-color-scheme: light) #EFE7D4") && tc.includes("(prefers-color-scheme: dark) #121212"), `theme-color: ${tc}`);
  });

  await test("TOC-2: the heading reads Contents, the title once stuck, Contents again when scrolled back", async () => {
    const label = d.querySelector("nav.toc .toc-title");
    expect(label.textContent === "Contents", `at the top: ${label.textContent}`);
    await scroll(3000);
    expect(label.textContent === "Specimen" && label.classList.contains("is-title"), `stuck: ${label.textContent}`);
    const inner = d.querySelector("nav.toc .toc-inner");
    near(rect(inner).top, parseFloat(w.getComputedStyle(inner).top), 1, "stuck below the menu");
    await scroll(0);
    expect(label.textContent === "Contents", `scrolled back: ${label.textContent}`);
  });

  await test("NAV-1: in XL the one menu tops the contents column and stays in the window", async () => {
    const menu = d.querySelector(".menu-rail .site-menu");
    expect(w.getComputedStyle(d.querySelector(".bar-menu")).display === "none", "the bar's copy shows in XL");
    near(rect(menu).left, rect(d.querySelector("nav.toc")).left, 1, "menu vs contents, left edges");
    await scroll(5000);
    const r = rect(menu);
    expect(r.top >= 0 && r.bottom <= 2.6 * 16 + 1, `menu at ${r.top}–${r.bottom} after scrolling`);
    await scroll(0);
  });

  await test("BAR-1d: the bar spans the window; section name and controls line up with the column", async () => {
    await scroll(4000);
    await scroll(3800);   // scrolling up shows the bar (BAR-1a)
    const bar = d.getElementById("bar");
    expect(bar.classList.contains("is-shown"), "the bar did not show on scrolling up");
    const b = rect(bar), a = rect(d.querySelector("article"));
    near(b.left, 0, 0.5, "bar's left");
    near(b.width, d.documentElement.clientWidth, 0.5, "bar's width");
    near(rect(bar.querySelector(".bar-section")).left, a.left, 1.5, "section name vs the column's left");
    // BAR-1d (2026-11-02): the controls sit at the window's right edge, 1.25rem in
    near(rect(bar.querySelector(".bar-controls")).right, d.documentElement.clientWidth - 1.25 * parseFloat(w.getComputedStyle(d.documentElement).fontSize), 1.5, "controls vs the window's right");
    await scroll(0);
  });

  await test("TERM-3: a definition opens a popup (no stub); More expands; see-also replaces it, with Back", async () => {
    expect(!d.querySelector(".def-stub"), "a definition stub is in the margin");
    trig("term-occurrent").click();
    await settle(200);
    const box = d.querySelector(".popup");
    expect(box && box.querySelector(".popup-title").textContent === "occurrent", "no popup titled occurrent");
    box.querySelector(".popup-more").click();
    expect(!box.querySelector(".term-more").hidden, "More did not expand");
    box.querySelector(".see-also a.term").click();
    await settle(100);
    expect(box.querySelector(".popup-title").textContent === "continuant", "see-also did not replace the content");
    box.querySelector(".popup-back").click();
    expect(box.querySelector(".popup-title").textContent === "occurrent", "Back did not restore it");
  });

  await test("ASIDE-3: resting on an aside previews it unfilled; a click pins it, filled", async () => {
    const t = trig("aside-2");
    t.scrollIntoView({ block: "center" });
    await settle(200);
    pointer("pointerover", t);
    await sleep(450);
    const stub = d.getElementById("aside-text-2");
    expect(stub.classList.contains("is-open") && stub.classList.contains("is-preview"), "no preview");
    expect(!t.querySelector(".circle").classList.contains("is-open"), "a preview filled its circle");
    t.click();
    await settle(100);
    expect(stub.classList.contains("is-open") && !stub.classList.contains("is-preview"), "not pinned");
    expect(t.querySelector(".circle").classList.contains("is-open"), "a pinned aside's circle is not filled");
    key("Escape");
    await scroll(0);
  });

  await test("ASIDE-3: every stub is one line closed; a one-line aside can be selected, filling its circle", async () => {
    const stubs = [...d.querySelectorAll("article .stub")];
    expect(stubs.length > 0, "no stubs");
    for (const s of stubs) expect(s.offsetHeight <= 1.5 * parseFloat(getComputedStyle(s).lineHeight), `a closed stub is taller than a line: ${s.id}`);
    const one = stubs.find((s) => s.dataset.single);
    expect(one, "no one-line aside on the specimen");
    one.scrollIntoView({ block: "center" });
    await settle(200);
    one._trigger.click();
    await settle(100);
    expect(one.classList.contains("is-open") && !one.classList.contains("is-preview"), "a one-line aside was not selected");
    expect(one._trigger.querySelector(".circle").classList.contains("is-open"), "its circle is not filled");
    expect(getComputedStyle(one).borderRightColor !== getComputedStyle(stubs.find((s) => s !== one && !s.classList.contains("is-open"))).borderRightColor, "a selected rule looks like an unselected one");
    key("Escape");
    await settle(100);
    expect(!one._trigger.querySelector(".circle").classList.contains("is-open"), "Esc left its circle filled");
    await scroll(0);
  });

  await test("POP-9: up to six pinned; the seventh closes the oldest", async () => {
    const ids = ["note-1", "note-2", "note-3", "note-4", "note-7 note-8", "term-occurrent", "term-looping-effect"];
    for (const id of ids) { trig(id).click(); await settle(80); }
    const open = titles(pinned());
    expect(open.length === 6, `${open.length} pinned: ${open}`);
    expect(!open.includes("Reference 1"), `the oldest stayed: ${open}`);
    expect(trig("note-1").getAttribute("aria-expanded") === "false", "the closed one's mark still says expanded");
    expect(pinned().every((b) => b.getAttribute("role") === "dialog" && !b.hasAttribute("aria-modal")), "not non-modal dialogs");
  });

  await test("POP-9: Esc closes the focused popup only; with none focused it does nothing", async () => {
    for (const id of ["note-1", "note-2", "note-3"]) { trig(id).click(); await settle(80); }
    const [a, b, c] = pinned();
    b.focus();
    key("Escape", b);
    await settle(50);
    expect(!b.isConnected, "the focused popup stayed");
    expect(a.isConnected && c.isConnected, "Esc closed another popup too");
    d.activeElement?.blur?.();
    key("Escape", d.body);
    await settle(50);
    expect(pinned().length === 2, `${pinned().length} after Esc with nothing focused`);
    c.focus();
    expect(w.getComputedStyle(c).zIndex > w.getComputedStyle(a).zIndex, "the one last touched is not on top");
  });

  // Reference 1 is the specimen's inline Pirsig quotation, #:loc "ch. 1";
  // reference 9 cites Pirsig with a remark (BIB-8, POP-7).
  await test("BIB-8, POP-7: a citation's popup is the work's card, the locator and remark under its title", async () => {
    trig("note-1").click(); await settle(250);
    let box = pinned()[0];
    const card = box?.querySelector(".ref-card");
    expect(card, "no card in the popup");
    expect(!box.querySelector(".popup-sep") && !box.querySelector(".popup-bib"), "the Chicago note is still there beside the card");
    expect(card.querySelector(".cover img[alt^='Cover of']"), "the card has no cover");
    expect(card.querySelector(".ref-title + .ref-loc")?.textContent.replace(/\s/g, " ") === "Chapter 1",
      `the locator under the title: ${card.querySelector(".ref-loc")?.textContent}`);
    expect(card.querySelector(".ref-fields dt")?.textContent === "Author", "the fields do not start with Author");
    expect(/Cited in 1 post/.test(card.textContent), `the card's last line: ${card.querySelector(".ref-cited")?.textContent}`);
    const ref = "/references/pirsigZenArtMotorcycle1991";
    expect(box.querySelector(".popup-title a")?.getAttribute("href") === ref, "the title is not a link to the work's page");
    expect(box.querySelector(".popup-open")?.getAttribute("href") === ref, "Open in new tab does not go to the work's page");
    await closeAll();
    trig("note-9").click(); await settle(250);
    box = pinned()[0];
    expect(box?.querySelector(".ref-title ~ .ref-remark em")?.textContent === "The 1991 Vintage paperback.", "no remark under the title");
    expect(!box.querySelector(".ref-loc"), "a locator shown where the citation has none");
  });

  await test("TERM-9: a sensed term's popup: title, definition, this essay's sense, then the rest; other terms have none", async () => {
    trig("term-looping-effect").click(); await settle(200);
    let box = pinned()[0];
    const body = box?.querySelector(".popup-term");
    const parts = [...body.children].map((c) => c.className || c.tagName.toLowerCase());
    expect(parts[0] === "definition" && parts[1] === "term-sense", `the order: ${parts}`);
    const sense = body.querySelector(".term-sense");
    expect(sense.querySelector(".sense-label")?.textContent === "In this essay:", "no label");
    expect(w.getComputedStyle(sense.querySelector("em")).fontStyle === "italic", "the sense is not italic");
    await closeAll();
    trig("term-occurrent").click(); await settle(200);
    box = pinned()[0];
    expect(!box.querySelector(".term-sense"), "a term with no sense on this page shows one");
    const order = [...box.querySelector(".popup-term").children].map((c) => c.className || c.tagName.toLowerCase());
    expect(order.indexOf("definition") < order.indexOf("p") || order.includes("see-also"), `occurrent's parts: ${order}`);
    await closeAll();
  });

  await test("VAL-4: a backlink's context is two lines until More, which needs no script", async () => {
    const entry = d.querySelector("#backlinks .context-entry");
    expect(entry, "the specimen has no Backlinks");
    const ctx = entry.querySelector(".context");
    const line = parseFloat(w.getComputedStyle(ctx).lineHeight);
    near(ctx.getBoundingClientRect().height, 2 * line, 2, "collapsed height");
    const more = entry.querySelector("details.context-more");
    more.open = true; await settle(50);
    expect(ctx.getBoundingClientRect().height > 2.5 * line, "More did not expand the context");
    more.open = false;
  });

  await test("POP-10: a pinned popup drags by its title bar and stays in the window; it resizes", async () => {
    trig("note-1").click();
    await settle(80);
    const box = pinned()[0], bar = box.querySelector(".popup-bar"), r = rect(bar);
    const x = r.left + 20, y = r.top + r.height / 2;
    pointer("pointerdown", bar, x, y);
    pointer("pointermove", d, x + 300, y + 200);
    pointer("pointermove", d, x + 400, y + 250);
    pointer("pointerup", d, x + 400, y + 250);
    const moved = rect(box);
    near(moved.left - r.left, 400, 1, "dragged across");
    pointer("pointerdown", bar, moved.left + 20, moved.top + 5);
    pointer("pointermove", d, -5000, -5000);
    pointer("pointerup", d, -5000, -5000);
    near(rect(box).left, 0, 0.5, "clamped left");
    near(rect(box).top, 0, 0.5, "clamped top");
    expect(w.getComputedStyle(box).resize === "both", "not resizable");
  });

  await test("POP-11: Dock in XL; the dock spans the contents and the left margin; dragging out undocks", async () => {
    trig("note-2").click();
    await settle(80);
    const box = pinned()[0];
    box.querySelector(".popup-dock").click();
    await settle(80);
    const dock = d.querySelector("nav.toc .dock");
    expect(box.parentElement === dock && box.classList.contains("is-docked"), "not docked");
    const want = rect(d.querySelector("nav.toc")).width + v("--margin-gap") + cssLen("--left-margin");
    near(rect(box).width, want, 1.5, "docked width");
    const bar = box.querySelector(".popup-bar"), r = rect(bar);
    pointer("pointerdown", bar, r.left + 20, r.top + 5);
    pointer("pointermove", d, r.left + 620, r.top + 105);
    pointer("pointerup", d, r.left + 620, r.top + 105);
    expect(!box.classList.contains("is-docked") && w.getComputedStyle(box).position === "fixed", "dragging out did not undock");
  });

  await test("POP-12: the scratch pad opens docked and keeps its text across a reload", async () => {
    w.localStorage.removeItem("scratch");
    expect(!d.querySelector(".site-menu .menu-scratch"), "Scratch is still in the menu");
    d.querySelector(".toc-scratch .scratch-open").click();
    await settle(100);
    let pad = d.querySelector(".popup.scratch");
    expect(pad?.classList.contains("is-docked"), "the pad did not open docked");
    const ta = pad.querySelector("textarea");
    expect(d.activeElement === ta, "the pad's text is not focused");
    ta.value = "A note to self: Hacking 1996, p. 23.";
    ta.dispatchEvent(new w.Event("input", { bubbles: true }));
    await sleep(600);
    await load("/specimen");
    d.querySelector(".toc-scratch .scratch-open").click();
    await settle(100);
    pad = d.querySelector(".popup.scratch");
    expect(pad.querySelector("textarea").value === "A note to self: Hacking 1996, p. 23.", "the text was lost");
    w.localStorage.removeItem("scratch");
  });

  await test("INDEX-1b: the essay index shows Title and Published only at tier S, Published on one line, Title filling the rest; every column from tier M", async () => {
    const visible = () => [...d.querySelectorAll(".index-table thead th")].filter((th) => w.getComputedStyle(th).display !== "none").map((th) => th.textContent.trim().replace(/\s+.*$/, ""));
    for (const [width, want] of [[390, "Title Published"], [900, "Title Published Edited Tags"], [1400, "Title Published Edited Tags"]]) {
      await load("/essays", width, 844);
      expect(visible().join(" ") === want, `${width}px: ${visible()}`);
    }
    await load("/essays", 390, 844);
    const table = d.querySelector(".index-table");
    for (const td of d.querySelectorAll(".index-table td.published")) {
      const lh = parseFloat(w.getComputedStyle(td).lineHeight) || 20;
      expect(rect(td).height < 2 * lh, `a Published date wraps: ${td.textContent}`);
    }
    const title = d.querySelector(".index-table th.title, .index-table thead th:first-child");
    const pub = d.querySelector(".index-table thead th.published");
    near(rect(title).width + rect(pub).width, rect(table).width, 2, "Title + Published vs the table");
    await load("/specimen", 2560, 1440);
  });

  await test("IMG-9: panels in a row at L, letters above their corners; Expand keeps the grid; stacked at S", async () => {
    await resize(1400, 900);
    const fig = d.getElementById("canalisation-panels");
    fig.scrollIntoView({ block: "center" });
    await settle(200);
    const panels = [...fig.querySelectorAll(".panel")];
    expect(panels.map((p) => p.querySelector(".panel-letter").textContent).join("") === "ABC", "letters are not A, B, C");
    const imgs = panels.map((p) => rect(p.querySelector(".panel-image")));
    near(imgs[1].top, imgs[0].top, 1, "B's top against A's");
    near(imgs[2].top, imgs[0].top, 1, "C's top against A's");
    near(imgs[0].width, imgs[1].width, 1, "A's width against B's");
    expect(imgs[0].right < imgs[1].left && imgs[1].right < imgs[2].left, "the panels overlap");
    for (const p of panels) {
      const l = rect(p.querySelector(".panel-letter")), i = rect(p.querySelector(".panel-image"));
      expect(l.bottom <= i.top + 0.5, `${p.textContent.trim()[0]}: the letter overlaps the image`);
      near(l.left, i.left, 0.5, "the letter's left against the image's");
    }
    const sum = imgs.reduce((a, r) => a + r.width, 0);
    near(rect(fig.querySelector(".panels")).width, rect(fig.querySelector(".exhibit-body")).width, 1, "the grid against the column");
    expect(sum > rect(fig.querySelector(".panels")).width * 0.9, "the panels leave too much gap");
    // spec 1.26: nothing but the letter with the image; the panels' captions
    // are lettered lines in the margin under the title, before the figure's
    // own caption, with no gap between them
    expect(!fig.querySelector(".exhibit-body .panel-caption, .exhibit-body li"), "a caption is still set with an image");
    const lines = [...fig.querySelectorAll(".exhibit-meta .panel-captions > li")];
    expect(lines.map((l) => l.querySelector(".panel-mark").textContent).join(" ") === "A. B. C.", "the caption lines are not A., B., C.");
    const body = rect(fig.querySelector(".exhibit-body")), title = rect(fig.querySelector(".exhibit-title"));
    for (const l of lines) expect(rect(l).left > body.right, "a caption line is not in the margin at L");
    expect(rect(lines[0]).top >= title.bottom - 0.5, "the caption lines are not under the title");
    near(rect(lines[1]).top, rect(lines[0]).bottom, 1, "a gap between the caption lines");
    expect(rect(fig.querySelector(".exhibit-caption")).top >= rect(lines[2]).bottom - 0.5, "the figure's caption is not after the lines");
    fig.querySelector(".expand").click();
    await settle(200);
    const stage = d.querySelector(".lb-stage"), grid = stage?.querySelector(".panels");
    expect(grid, "Expand shows no grid");
    const tops = [...grid.querySelectorAll(".panel-image")].map((x) => rect(x).top);
    expect(tops.length === 3 && Math.abs(tops[0] - tops[2]) < 1, "the expanded panels are not in a row");
    expect(rect(grid).width > rect(fig.querySelector(".panels")).width * 1.3, "the expanded grid is no wider than the column's");
    expect(d.querySelectorAll(".lb-foot .panel-captions > li").length === 3, "the lightbox's foot lacks the caption lines");
    key("Escape", d.body);
    await settle(100);
    await resize(390, 844);
    fig.scrollIntoView({ block: "start" });
    await settle(200);
    const stacked = panels.map((p) => rect(p.querySelector(".panel-image")));
    near(stacked[1].left, stacked[0].left, 1, "B's left against A's at S");
    expect(stacked[0].bottom < stacked[1].top && stacked[1].bottom < stacked[2].top, "the panels do not stack at S");
    expect(panels.every((p) => w.getComputedStyle(p.querySelector(".panel-letter")).display !== "none"), "letters lost at S");
    expect(rect(fig.querySelector(".panel-captions")).top >= stacked[2].bottom, "the caption lines are not below the figure at S");
    await load("/specimen", 2560, 1440);
  });

  await test("LAYOUT-4d: a short quotation shrink-wraps, its attribution under its last words; a long one fills the column; indent and #:italic hold", async () => {
    await resize(1400, 900);
    const col = rect(d.querySelector("article p"));
    const quotes = [...d.querySelectorAll("article blockquote.epigraph, article blockquote.quote")];
    const find = (t) => quotes.find((q) => q.textContent.includes(t));
    const epi = find("same"), marked = find("cycle called yourself"), darwin = find("grandeur");
    const roman = quotes.find((q) => q.matches(".epigraph.roman")), italic = quotes.find((q) => q.matches(".quote.italic"));
    for (const [name, q] of [["the epigraph", epi], ["the marked quotation", marked]]) {
      expect(q, `no ${name} on the specimen`);
      const b = rect(q), f = rect(q.querySelector("footer"));
      expect(b.width < col.width * 0.9, `${name} fills the column`);
      expect(b.width >= col.width / 2 - 1, `${name} is under half the column`);
      near(f.right, b.right, 1, `${name}'s attribution against its block`);
      expect(b.left > col.left + 10, `${name} lost its indent`);
      expect(w.getComputedStyle(q.querySelector("footer")).fontStyle === "normal", `${name}'s attribution is not roman`);
    }
    // the epigraph's longest line ends at the block's right edge (no floor here)
    const range = d.createRange(); range.selectNodeContents(epi.querySelector("p"));
    const lines = [...range.getClientRects()];
    if (rect(epi).width > col.width / 2 + 1) near(Math.max(...lines.map((r) => r.right)), rect(epi).right, 2, "the epigraph's longest line against its block");
    near(rect(darwin).right, col.right, 2, "a long quotation no longer fills the column");
    expect(w.getComputedStyle(epi).fontStyle === "italic" && w.getComputedStyle(roman).fontStyle === "normal", "the epigraph's #:italic");
    expect(w.getComputedStyle(darwin).fontStyle === "normal" && w.getComputedStyle(italic).fontStyle === "italic", "the block quotation's #:italic");
    expect(w.getComputedStyle(epi.querySelector("em")).fontStyle === "normal", "emphasis in the italic epigraph is not roman");
  });

  await test("IMG-2: #:width 0.5 is half the column, flush left, words in the margin, Expand on its corner; whole column at S", async () => {
    await resize(1400, 900);
    const fig = d.getElementById("pillar");
    fig.scrollIntoView({ block: "center" });
    await settle(200);
    const body = rect(fig.querySelector(".exhibit-body")), img = rect(fig.querySelector("img"));
    const col = rect(d.querySelector("article p"));
    near(img.left, col.left, 1, "the image's left against the text's");
    near(img.width, col.width / 2, 2, "the image against half the column");
    expect(rect(fig.querySelector(".exhibit-title")).left > col.right, "the title is not in the margin at L");
    const ex = rect(fig.querySelector(".expand"));
    expect(ex.right <= img.right + 0.5 && ex.right > img.right - 20 && ex.top < img.top + 20, "Expand is not on the image's top-right corner");
    fig.querySelector(".expand").click();
    await settle(200);
    expect(rect(d.querySelector(".lb-stage img")).width > img.width * 1.1 || rect(d.querySelector(".lb-stage img")).height > img.height * 1.1,
      "Expand keeps the fraction");
    key("Escape", d.body);
    await settle(100);
    await resize(390, 844);
    fig.scrollIntoView({ block: "start" });
    await settle(200);
    const narrow = rect(fig.querySelector("img")), ncol = rect(fig.querySelector(".exhibit-title"));
    near(narrow.width, ncol.width, 2, "the fraction is not dropped at S");
    await load("/specimen", 2560, 1440);
  });

  await test("Tier L: Pin, no Dock, contents in the bar; tier M: no Pin, one popup at a time, the pinned closed", async () => {
    await resize(1400, 900);
    expect(tier() === "L", `tier ${tier()} at 1,400`);
    trig("note-1").click();
    await settle(80);
    const box = pinned()[0];
    expect(box && !box.querySelector(".popup-pin").hidden && box.querySelector(".popup-dock").hidden, "Pin/Dock wrong in L");
    expect(w.getComputedStyle(d.querySelector(".bar-menu")).display !== "none", "no menu in the bar in L");
    await resize(900, 900);
    expect(tier() === "M", `tier ${tier()} at 900`);
    expect(pinned().length === 0, "pinned popups survived the drop to M");
    trig("note-1").click(); await settle(80);
    trig("note-2").click(); await settle(80);
    const boxes = [...d.querySelectorAll(".popup")];
    expect(boxes.length === 1 && boxes[0].querySelector(".popup-pin").hidden, `${boxes.length} popups in M, or a Pin button`);
    key("Escape", d.body);
    await settle(50);
    expect(!d.querySelector(".popup"), "Esc did not close the one popup in M");
  });

  await test("Tier S: the bar's menu is the monogram and the chevron, no name (NAV-1, 2026-11-02)", async () => {
    await resize(390, 844);
    expect(tier() === "S", `tier ${tier()} at 390`);
    const m = d.querySelector(".bar-menu");
    expect(!m.querySelector(".site-name, .site-name-short"), "the name is still in the bar's menu");
    expect(w.getComputedStyle(m.querySelector(".menu-icon")).display !== "none", "the monogram does not show");
    expect(w.getComputedStyle(m.querySelector(".chevron")).display !== "none", "the chevron does not show");
  });

  await senseElsewhere();

  const out = document.getElementById("results");
  out.textContent = JSON.stringify(results);
  out.hidden = false;
  await done(out.textContent);
}

// Release the page's load event, so Chrome dumps or captures it (browser_test.py).
async function done(body = "") {
  document.title = "done";
  // The page under test may still be fetching something (a card's cover,
  // lazily, BIB-8), which would hold the frame, and so this page's load
  // event, open; the results are in hand, so let it go.
  if (params.get("run")) await new Promise((r) => { frame.onload = r; frame.src = "about:blank"; });
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  await fetch("/__results", { method: "POST", body });
}

// On a touch device (the browser told it has no hover and a coarse
// pointer): the bar at the bottom, taller, always there, its menu three
// bars; no scratch pad; a definition as a popin (BAR-1, NAV-1, POP-5, POP-12).
async function senseElsewhere() {
  await load("/placeholder", 1680, 1050);
  await test("TERM-9: the same term on another page, without a sense, has none in its popup", async () => {
    trig("term-looping-effect").click(); await settle(200);
    const box = d.querySelector(".popup");
    expect(box?.querySelector(".popup-term .definition"), "no definition popup on the placeholder");
    expect(!box.querySelector(".term-sense"), "the specimen's sense leaked onto another page");
  });
}

async function touchTests() {
  await load("/specimen", 390, 844);
  await test("The browser is a touch device (the rest assume one)", async () => {
    expect(w.matchMedia("(hover: none)").matches, "the page sees a hovering pointer; see TOUCH in browser_test.py");
  });
  await test("BAR-1: the bar is at the bottom, at least 52 px tall, shown without scrolling, and stays", async () => {
    const bar = d.getElementById("bar");
    expect(bar.classList.contains("is-shown"), "not shown at the top of the page");
    const r = rect(bar);
    near(r.bottom, w.innerHeight, 1, "bar's bottom vs the window's");
    expect(r.height >= 52, `bar ${r.height}px tall`);
    await scroll(3000);
    await scroll(3500);
    await sleep(2300);
    expect(bar.classList.contains("is-shown") && rect(bar).bottom <= w.innerHeight + 1, "hid on scrolling down or when idle");
    const controls = [...bar.querySelectorAll("button, summary")].filter((b) => b.getClientRects().length);
    expect(controls.every((b) => rect(b).height >= 44 && rect(b).width >= 44), "a control smaller than 44 × 44 px");
  });
  await test("NAV-1, BRAND-1: the bar's menu is the monogram, named, and opens upward, flush left, in the sans", async () => {
    const m = d.querySelector(".bar-menu");
    const shown = (sel) => { const e = m.querySelector(sel); return e && w.getComputedStyle(e).display !== "none"; };
    expect(shown(".menu-icon") && !shown(".chevron") && !m.querySelector(".site-name, .site-name-short"), "the name or the chevron shows, or the icon does not");
    expect(m.querySelector("summary").getAttribute("aria-label") === "Site menu", "no accessible name");
    const bg = w.getComputedStyle(m.querySelector(".menu-icon")).backgroundImage;
    expect(/\/assets\/brand\/logo\.svg/.test(bg), `the icon is ${bg}`);
    const img = new w.Image();
    await new Promise((r) => { img.onload = img.onerror = r; img.src = "/assets/brand/logo.svg"; });
    expect(img.naturalWidth > 0, "the monogram does not load");
    m.open = true;
    expect(rect(m.querySelector("nav")).bottom <= rect(m).top + 1, "the menu does not open upward");
    const nav = rect(m.querySelector("nav")), link = m.querySelector("nav a");
    near(nav.left, 0, 0.5, "the menu's left edge vs the screen's");
    near(nav.bottom, rect(d.getElementById("bar")).top, 1, "the menu's foot vs the bar's top");
    expect(/system-ui/.test(w.getComputedStyle(link).fontFamily), "the menu is not in the sans");
    expect(parseFloat(w.getComputedStyle(link).fontSize) >= 16, `menu text ${w.getComputedStyle(link).fontSize}`);
    m.open = false;
  });
  await test("POP-12: no scratch pad on touch devices", async () => {
    expect(!d.querySelector(".menu-scratch"), "Scratch in a menu");
    expect(!d.querySelector(".toc-scratch"), "Scratch under the contents");
  });
  await test("POP-5: a definition opens as a popin", async () => {
    await scroll(0);
    trig("term-occurrent").click();
    await settle(200);
    const box = d.querySelector(".popup");
    expect(box?.classList.contains("is-popin") && !box.querySelector(".popup-pin:not([hidden])"), "not a popin, or it has Pin");
  });
  const out = document.getElementById("results");
  out.textContent = JSON.stringify(results);
  await done(out.textContent);
}

// ── Screenshot scenarios ─────────────────────────────────────────────────

const SCENARIOS = {
  async top() {},
  // the contents stuck under the menu, headed by the title
  async stuck() { await scroll(d.getElementById("furniture").offsetTop + 200); },
  // the bar shown by scrolling up, held by focus inside it
  async bar() {
    await scroll(d.getElementById("marks").offsetTop + 400);
    await scroll(d.getElementById("marks").offsetTop + 200);
    d.querySelector("#bar .bar-section").focus();
    await settle(300);
  },
  // three pinned popups, one dragged, one docked
  async pins() {
    await scroll(d.getElementById("notes-asides").offsetTop - 160);
    for (const id of ["note-1", "term-looping-effect", "note-2"]) { trig(id)?.click(); await settle(100); }
    const boxes = [...d.querySelectorAll(".popup.is-pinned")];
    boxes[0]?.querySelector(".popup-dock")?.click();
    await settle(100);
    const box = boxes[1], bar = box?.querySelector(".popup-bar");
    if (bar) {
      const r = bar.getBoundingClientRect();
      pointer("pointerdown", bar, r.left + 20, r.top + 5);
      pointer("pointermove", d, r.left + 260, r.top - 120);
      pointer("pointerup", d, r.left + 260, r.top - 120);
    }
    boxes[2]?.focus();
    await settle(200);
  },
  // the bar's contents, opened from the section name (in the sans)
  async toc() {
    await SCENARIOS.bar();
    d.querySelector("#bar .bar-section").click();
    await settle(200);
  },
  // the bar's menu, open (on a touch device, at the bottom)
  async menu() {
    await scroll(d.getElementById("lists").offsetTop - 200);
    d.querySelector(".bar-menu").open = true;
    await settle(100);
  },
  // the pad, with text in it
  async pad() {
    w.localStorage.setItem("scratch", "Ask about canalisation vs. constraint.\nCheck Hacking 1996, p. 23, against the lecture.\n\nOyama on the parity thesis: ch. 2?");
    await scroll(d.getElementById("column").offsetTop);
    d.querySelector(".toc-scratch .scratch-open").click();
    await settle(200);
    d.activeElement?.blur?.();
    await settle(100);
  },
  // a definition, opened, with More
  async def() {
    const t = trig("term-occurrent");
    t.scrollIntoView({ block: "start" });
    w.scrollBy(0, -80);
    await settle(200);
    t.click();
    await settle(200);
    d.querySelector(".popup .popup-more")?.click();
    await settle(100);
  },
  // BIB-8: a note popup with the reference card and its cover
  async card() {
    const t = trig(params.get("target") || "note-1");
    t.scrollIntoView({ block: "center" });
    w.scrollBy(0, -160);
    await settle(200);
    t.click();
    await settle(400);
    for (const img of d.querySelectorAll(".popup img")) { img.loading = "eager"; await img.decode().catch(() => {}); }
    await settle(200);
  },
  // VAL-4: the Backlinks section at the foot of the page, one entry opened
  async backlinks() {
    const s = d.getElementById("backlinks");
    w.scrollTo({ top: s.offsetTop - 120, behavior: "instant" });
    await settle(300);
  },
  // NAV-1: the menu open, wherever it stands on the page
  async menuopen() {
    const m = d.querySelector(".menu-rail .site-menu") || d.querySelector(".site-menu");
    m.open = true;
    await settle(200);
  },
  // TERM-8: a glossary entry's Used in
  async usedin() {
    const u = d.querySelector("#looping-effect") || d.querySelector(".glossary-entry");
    w.scrollTo({ top: u.offsetTop - 60, behavior: "instant" });
    await settle(300);
  },
  // the foot of the page (About's Start here)
  async bottom() { w.scrollTo({ top: d.documentElement.scrollHeight, behavior: "instant" }); await settle(300); },
  // BIB-9: a work's Cited in
  async citedin() {
    const s = d.getElementById("cited-in");
    w.scrollTo({ top: s.offsetTop - 40, behavior: "instant" });
    await settle(300);
  },
  // LAYOUT-4d: the specimen's marked quotation (BIB-9), its attribution written by the build
  async quote() {
    const q = [...d.querySelectorAll("article blockquote.quote")].find((x) => x.textContent.includes("cycle called yourself"));
    q.scrollIntoView({ block: "center" });
    await settle(300);
  },
  // IMG-2: the specimen's half-width figure, loaded
  async pillar() {
    const f = d.getElementById("pillar");
    for (const img of f.querySelectorAll("img")) { img.loading = "eager"; await img.decode().catch(() => {}); }
    f.scrollIntoView({ block: "center" });
    await settle(300);
  },
  // IMG-9: the specimen's panels, every image loaded; `expand` opens them
  async panels() {
    const f = d.getElementById("canalisation-panels");
    for (const img of f.querySelectorAll("img")) { img.loading = "eager"; await img.decode().catch(() => {}); }
    f.scrollIntoView({ block: "center" });
    await settle(300);
    if (params.get("expand")) {
      f.querySelector(".expand").click();
      await settle(200);
      for (const img of d.querySelectorAll(".lightbox img")) await img.decode().catch(() => {});
      await settle(300);
    }
  },
  // a page from its top, with every image loaded (a work's cover)
  async loaded() {
    for (const img of d.querySelectorAll("article img")) { img.loading = "eager"; await img.decode().catch(() => {}); }
    await settle(200);
  },
};

async function show(name, theme) {
  if (params.get("w")) { frame.style.width = `${params.get("w")}px`; frame.style.height = `${params.get("h")}px`; }
  const path = params.get("page") || "/specimen";
  await load(path);
  if (theme === "dark" || theme === "light") {
    w.localStorage.setItem("theme", theme);
    await load(path);
  }
  await SCENARIOS[name]?.();
  w.localStorage.removeItem("theme");
  w.localStorage.removeItem("scratch");
  await done();
}

if (params.get("run") === "tests") { document.body.classList.add("tests"); tests(); }
else if (params.get("run") === "touch") touchTests();
else if (params.get("show")) show(params.get("show"), params.get("theme"));
