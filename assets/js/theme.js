(function () {
  // THEME-1/6: Auto → Light → Dark. Auto removes data-theme so CSS follows the system live.
  var root = document.documentElement, button = document.getElementById("theme");
  if (!button) return;
  var order = ["auto", "light", "dark"], names = { auto: "Auto", light: "Light", dark: "Dark" };
  function current() { return root.dataset.theme || "auto"; }
  function show() {
    var c = current();
    button.dataset.choice = c;
    button.setAttribute("aria-label", "Theme: " + names[c] + ". Change theme");
    button.title = "Theme: " + names[c];
  }
  function set(choice) {
    if (choice == "auto") delete root.dataset.theme; else root.dataset.theme = choice;
    try { choice == "auto" ? localStorage.removeItem("theme") : localStorage.setItem("theme", choice); } catch (e) {}
    show();
  }
  button.addEventListener("click", function () { set(order[(order.indexOf(current()) + 1) % 3]); });
  addEventListener("storage", function (e) {
    if (e.key == "theme") { if (e.newValue) root.dataset.theme = e.newValue; else delete root.dataset.theme; show(); }
  });
  show();
  button.hidden = false;
})();
