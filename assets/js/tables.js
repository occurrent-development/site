// Tables: sorting (TABLE-5) and a header row that stays in view on long
// tables (TABLE-4). Loaded by site.js only on pages with such a table.

const LONG = 15;   // body rows from which the header row stays in view

// ── Sorting ───────────────────────────────────────────────────────────────

const MONTHS = ["january", "february", "march", "april", "may", "june", "july",
  "august", "september", "october", "november", "december"];

// A comparable value: numbers (with separators, %, currency, units and
// ranges, which sort by their first number), dates, or text.
function value(cell) {
  const raw = (cell.dataset.sort ?? cell.textContent).trim();
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
        h.querySelector(".sort-mark").textContent = d === 1 ? "▲" : d === -1 ? "▼" : "";
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

for (const table of document.querySelectorAll(".table-wrap table")) {
  if (table.matches("[data-sortable]")) makeSortable(table);
  if (table.tBodies[0]?.rows.length >= LONG) stickyHeader(table);
}
