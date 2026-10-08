(function () {
  // Specimen only: cycle the THEME-4 candidate colours so they can be judged by eye (D1).
  var candidates = {
    light: { bg: ["#EFE7D4", "#EAE0C8", "#E6DCC3"], text: ["#000000", "#111111"] },
    dark:  { bg: ["#121212", "#151514", "#181716"], text: ["#D2D2D0", "#C8C8C5", "#DADAD6"] }
  };
  var root = document.documentElement, dark = matchMedia("(prefers-color-scheme: dark)");
  var pick = { light: { bg: 0, text: 0 }, dark: { bg: 0, text: 0 } };
  try { pick = JSON.parse(localStorage.getItem("specimen-colours")) || pick; } catch (e) {}

  function theme() { return root.dataset.theme || (dark.matches ? "dark" : "light"); }
  function lum(hex) {
    var c = [1, 3, 5].map(function (i) {
      var v = parseInt(hex.substr(i, 2), 16) / 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  function ratio(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  function computed(token) {
    // Resolve a light-dark() token to hex via a probe element.
    var probe = document.createElement("span");
    probe.style.color = "var(" + token + ")";
    panel.appendChild(probe);
    var rgb = getComputedStyle(probe).color.match(/\d+/g).slice(0, 3);
    probe.remove();
    return "#" + rgb.map(function (n) { return (+n).toString(16).padStart(2, "0"); }).join("").toUpperCase();
  }

  var box = document.createElement("details");
  box.className = "colours";
  box.open = innerWidth > 700;
  box.innerHTML = "<summary>Candidate colours</summary>";
  var panel = document.createElement("div");
  box.appendChild(panel);
  document.body.appendChild(box);

  function render() {
    var t = theme(), c = candidates[t], p = pick[t];
    var bg = c.bg[p.bg], text = c.text[p.text];
    root.style.setProperty("--bg", bg);
    root.style.setProperty("--text", text);
    var muted = computed("--text-muted"), accent = computed("--accent");
    panel.innerHTML =
      "<p>" + (t == "dark" ? "Dark" : "Light") + " theme</p>" +
      "<p><button type=button data-k=bg><span class=swatch style='background:" + bg + "'></span>Background " +
      bg + " (" + (p.bg + 1) + "/" + c.bg.length + ")</button>" +
      "<button type=button data-k=text><span class=swatch style='background:" + text + "'></span>Text " +
      text + " (" + (p.text + 1) + "/" + c.text.length + ")</button></p>" +
      "<p>Contrast: text " + ratio(text, bg).toFixed(1) + " · muted " + ratio(muted, bg).toFixed(1) +
      " · accent " + ratio(accent, bg).toFixed(1) + "</p>";
  }
  panel.addEventListener("click", function (e) {
    var b = e.target.closest("button");
    if (!b) return;
    var t = theme(), k = b.dataset.k;
    pick[t][k] = (pick[t][k] + 1) % candidates[t][k].length;
    try { localStorage.setItem("specimen-colours", JSON.stringify(pick)); } catch (e) {}
    render();
  });
  new MutationObserver(render).observe(root, { attributes: true, attributeFilter: ["data-theme"] });
  dark.addEventListener("change", render);
  render();
})();
