// Tables: sorting (TABLE-5) and a header row that stays in view on long
// tables (TABLE-4). Loaded by site.js only on pages with such a table.

const LONG = 15;   // body rows from which the header row stays in view

// ── Sorting ───────────────────────────────────────────────────────────────

const MONTHS = ["january", "february", "march", "april", "may", "june", "july",
  "august", "september", "october", "november", "december"];

// A comparable value: numbers (with separators, %, currency, units and
// ranges, which sort by their first number), dates, or text.
function value(cell) {
  const raw = (cell.querySelector("[data-sort]")?.dataset.sort ?? cell.dataset.sort ?? cell.textContent).trim();
  const iso = raw.match(/^(\d{4})-(\d{2})(?:-(\d{2}))?$/);
  if (iso) return { kind: 1, v: Date.UTC(+iso[1], +iso[2] - 1, +(iso[3] || 1)) };
  const dmy = raw.match(/^(\d{1,2}) ([A-Za-z]+) (\d{4})$/);
  if (dmy && MONTHS.includes(dmy[2].toLowerCase())) {
    return { kind: 1, v: Date.UTC(+dmy[3], MONTHS.indexOf(dmy[2].toLowerCase()), +dmy[1]) };
  }
  const num = raw.replace(/[   ,]/g, "").match(/^[−–+-]?[$€£¥]?(\d+(?:\.\d+)?)/);
  if (num) {
    const sign = /^[−–-]/.test(raw) ? -1 : 1;
    return { kind: 0, v: sign * parseFloat(num[1]) };
  }
  return { kind: 2, v: raw };
}

function compare(a, b) {
  if (a.kind !== b.kind) return a.kind - b.kind;
  if (a.kind === 2) return a.v.localeCompare(b.v, undefined, { numeric: true, sensitivity: "base" });
  return a.v - b.v;
}

function makeSortable(table) {
  const tbody = table.tBodies[0];
  const original = [...tbody.rows];
  const headers = [...table.tHead.rows[0].cells];
  let state = { col: -1, dir: 0 };   // dir: 1 ascending, -1 descending, 0 original

  headers.forEach((th, col) => {
    if (th.hasAttribute("data-nosort")) return;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "sort";
    button.append(...th.childNodes, Object.assign(document.createElement("span"), { className: "sort-mark", ariaHidden: "true" }));
    th.append(button);
    button.addEventListener("click", () => {
      const dir = state.col === col ? (state.dir === 1 ? -1 : state.dir === -1 ? 0 : 1) : 1;
      state = { col, dir };
      const rows = dir === 0 ? original
        : [...original].sort((r1, r2) => dir * compare(value(r1.cells[col]), value(r2.cells[col])));
      tbody.append(...rows);
      headers.forEach((h, i) => {
        const d = i === col ? dir : 0;
        if (d) h.setAttribute("aria-sort", d === 1 ? "ascending" : "descending");
        else h.removeAttribute("aria-sort");
        const mark = h.querySelector(".sort-mark");
        if (mark) mark.textContent = d === 1 ? "▲" : d === -1 ? "▼" : "";
      });
      table.dispatchEvent(new CustomEvent("sorted"));
    });
  });
}

// ── A header row that stays in view (TABLE-4) ───────────────────────────
// CSS cannot pin a header to the viewport from inside a sideways-scrolling
// container, so a copy of the header row is shown at the top of the
// viewport while the table passes beneath it.

function stickyHeader(table) {
  const scroller = table.closest(".table-scroll");
  const holder = document.createElement("div");
  holder.className = "sticky-head";
  holder.setAttribute("aria-hidden", "true");
  const copy = document.createElement("table");
  holder.append(copy);
  scroller.parentElement.append(holder);

  function rebuild() {
    copy.className = table.className;
    copy.replaceChildren(table.tHead.cloneNode(true));
    for (const b of copy.querySelectorAll("button")) b.tabIndex = -1;
    const widths = [...table.tHead.rows[0].cells].map((c) => c.getBoundingClientRect().width);
    copy.style.width = `${table.getBoundingClientRect().width}px`;
    [...copy.tHead.rows[0].cells].forEach((c, i) => { c.style.width = `${widths[i]}px`; c.style.boxSizing = "border-box"; });
  }

  function update() {
    const bar = document.querySelector(".bar.is-shown");
    const top = bar ? bar.getBoundingClientRect().bottom : 0;
    const head = table.tHead.getBoundingClientRect();
    const t = table.getBoundingClientRect();
    const show = head.top < top && t.bottom - head.height > top;
    holder.classList.toggle("is-shown", show);
    if (show) {
      const s = scroller.getBoundingClientRect();
      holder.style.top = `${top}px`;
      holder.style.left = `${s.left}px`;
      holder.style.width = `${s.width}px`;
      copy.style.transform = `translateX(${-scroller.scrollLeft}px)`;
    }
  }

  rebuild();
  // copies forward clicks to the real header, so sorting works from either
  holder.addEventListener("click", (e) => {
    const th = e.target.closest("th");
    if (!th) return;
    const i = [...th.parentElement.cells].indexOf(th);
    table.tHead.rows[0].cells[i].querySelector("button")?.click();
  });
  table.addEventListener("sorted", rebuild);
  addEventListener("scroll", update, { passive: true });
  scroller.addEventListener("scroll", update, { passive: true });
  addEventListener("resize", () => { rebuild(); update(); });
  update();
}

// ── Tag filter on the home page (INDEX-3) ──────────────────────────────
// The Tags heading opens a list of every tag; the chosen ones form a set,
// shown above the table, from which each can be removed. A row shows when
// it has every tag in the set. The set is kept in the address (?tags=a,b).

const SVG = "http://www.w3.org/2000/svg";
function drawn(d, cls) {
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", "0 0 12 12");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("class", cls);
  const path = document.createElementNS(SVG, "path");
  for (const [k, v] of Object.entries({ d, fill: "none", stroke: "currentColor", "stroke-width": "1.3",
    "stroke-linecap": "round", "stroke-linejoin": "round" })) path.setAttribute(k, v);
  svg.append(path);
  return svg;
}
const CHEVRON = "M2.5 4.5 6 8l3.5-3.5";
const CROSS = "M3 3l6 6M9 3l-6 6";

function tagFilter(index) {
  const th = index.querySelector("th[data-tag-filter]");
  const rows = [...index.querySelectorAll("tbody tr")];
  const tagsOf = (r) => (r.dataset.tags ? r.dataset.tags.split("|") : []);
  const counts = new Map();
  for (const r of rows) for (const t of tagsOf(r)) counts.set(t, (counts.get(t) || 0) + 1);
  const all = [...counts.keys()].sort((a, b) => a.localeCompare(b));
  const chosen = new Set();

  // the heading becomes the button that opens the list
  const button = document.createElement("button");
  button.type = "button";
  button.className = "tag-menu-button";
  button.setAttribute("aria-haspopup", "true");
  button.setAttribute("aria-expanded", "false");
  button.append(...th.childNodes, drawn(CHEVRON, "chevron"));
  th.append(button);

  const panel = document.createElement("div");
  panel.className = "tag-menu";
  panel.hidden = true;
  panel.setAttribute("role", "group");
  panel.setAttribute("aria-label", "Show essays tagged");
  for (const t of all) {
    const label = document.createElement("label");
    const box = Object.assign(document.createElement("input"), { type: "checkbox", value: t });
    label.append(box, ` ${t}`, Object.assign(document.createElement("span"), { className: "count", textContent: counts.get(t) }));
    panel.append(label);
  }
  index.append(panel);

  const none = Object.assign(document.createElement("p"), { className: "tag-none", textContent: "No essay has all of these tags." });
  none.hidden = true;
  index.append(none);

  const set = document.createElement("p");
  set.className = "tag-set";
  set.hidden = true;
  index.prepend(set);

  // tags in the rows become buttons that add (or remove) themselves
  for (const span of index.querySelectorAll("td .tag")) {
    const b = Object.assign(document.createElement("button"), { type: "button", className: "tag", textContent: span.textContent });
    b.dataset.tag = span.textContent;
    span.replaceWith(b);
  }

  function update(push) {
    for (const r of rows) r.hidden = ![...chosen].every((t) => tagsOf(r).includes(t));
    none.hidden = rows.some((r) => !r.hidden);
    for (const box of panel.querySelectorAll("input")) box.checked = chosen.has(box.value);
    for (const b of index.querySelectorAll("td button.tag")) {
      b.classList.toggle("is-current", chosen.has(b.dataset.tag));
      b.setAttribute("aria-pressed", String(chosen.has(b.dataset.tag)));
    }
    th.classList.toggle("is-filtered", chosen.size > 0);
    set.replaceChildren();
    set.hidden = chosen.size === 0;
    if (chosen.size) {
      set.append(Object.assign(document.createElement("span"), { className: "tag-set-label", textContent: "Tagged" }));
      for (const t of [...chosen].sort((a, b) => a.localeCompare(b))) {
        const b = Object.assign(document.createElement("button"), { type: "button", className: "chip" });
        b.dataset.remove = t;
        b.setAttribute("aria-label", `Remove ${t}`);
        b.append(t, drawn(CROSS, "cross"));
        set.append(b);
      }
      if (chosen.size > 1) {
        const clear = Object.assign(document.createElement("button"), { type: "button", className: "clear", textContent: "clear" });
        clear.dataset.remove = "";
        set.append(clear);
      }
    }
    if (!panel.hidden) place();
    if (push) {
      const url = new URL(location.href);
      url.searchParams.delete("tag");
      if (chosen.size) url.searchParams.set("tags", [...chosen].join(","));
      else url.searchParams.delete("tags");
      history.replaceState(null, "", url.pathname + url.search.replace(/%2C/g, ",") + url.hash);
    }
  }

  // below the heading, which moves when the set above the table appears
  function place() {
    const i = index.getBoundingClientRect(), h = th.getBoundingClientRect();
    panel.style.top = `${h.bottom - i.top + 4}px`;
  }
  function open() {
    th.scrollIntoView({ block: "nearest" });
    panel.hidden = false;
    button.setAttribute("aria-expanded", "true");
    place();
    panel.querySelector("input")?.focus();
  }
  function shut(focus) {
    if (panel.hidden) return;
    panel.hidden = true;
    button.setAttribute("aria-expanded", "false");
    if (focus) button.focus();
  }

  button.addEventListener("click", (e) => { e.stopPropagation(); panel.hidden ? open() : shut(); });
  panel.addEventListener("change", (e) => {
    const box = e.target;
    if (box.checked) chosen.add(box.value); else chosen.delete(box.value);
    update(true);
  });
  panel.addEventListener("keydown", (e) => { if (e.key === "Escape") { e.stopPropagation(); shut(true); } });
  document.addEventListener("click", (e) => {
    // (a click on the pinned copy of the heading is forwarded to the button)
    if (!panel.contains(e.target) && !e.target.closest("th[data-tag-filter], .sticky-head")) shut();
  });
  index.addEventListener("focusout", (e) => {
    if (!panel.hidden && e.relatedTarget && !panel.contains(e.relatedTarget) && e.relatedTarget !== button) shut();
  });

  set.addEventListener("click", (e) => {
    const b = e.target.closest("button[data-remove]");
    if (!b) return;
    if (b.dataset.remove) chosen.delete(b.dataset.remove); else chosen.clear();
    update(true);
    (set.querySelector("button") || button).focus();
  });
  index.addEventListener("click", (e) => {
    const b = e.target.closest("td button.tag");
    if (!b) return;
    if (chosen.has(b.dataset.tag)) chosen.delete(b.dataset.tag); else chosen.add(b.dataset.tag);
    update(true);
  });

  const params = new URL(location.href).searchParams;
  for (const t of (params.get("tags") || params.get("tag") || "").split(",")) if (counts.has(t)) chosen.add(t);
  update(false);
}

const index = document.querySelector(".essay-index");
if (index) tagFilter(index);

for (const table of document.querySelectorAll(".table-wrap table")) {
  if (table.matches("[data-sortable]")) makeSortable(table);
  if (table.tBodies[0]?.rows.length >= LONG) stickyHeader(table);
}
