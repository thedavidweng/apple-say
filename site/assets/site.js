// Explicit i18n detection: when the browser language does not match the page
// language, reveal the top banner offering a switch. The user's explicit
// choice (switch or dismiss) is remembered and never overridden afterwards.
(function () {
  var KEY = "apple-say-lang";
  function get() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  function set(v) {
    try { localStorage.setItem(KEY, v); } catch (e) { /* private mode */ }
  }
  var pageLang = document.documentElement.lang.toLowerCase().indexOf("zh") === 0 ? "zh" : "en";
  var browserLang = (navigator.language || "en").toLowerCase().indexOf("zh") === 0 ? "zh" : "en";
  var banner = document.getElementById("lang-banner");
  if (!banner) return;

  var chosen = get();
  if (!chosen && browserLang !== pageLang) {
    banner.hidden = false;
  }

  var switcher = document.getElementById("lang-switch");
  if (switcher) {
    switcher.addEventListener("click", function () {
      set(pageLang === "zh" ? "en" : "zh"); // remember the language they switched to
    });
  }
  var dismiss = document.getElementById("lang-dismiss");
  if (dismiss) {
    dismiss.addEventListener("click", function () {
      set(pageLang); // remember they chose to stay
      banner.hidden = true;
    });
  }
})();

// Hero intro: the editor's line is spoken word by word over a live waveform,
// which flows into Play as the camera pulls back to the captured window.
// The line and geometry mirror public/screenshot.webp; update them with it.
(function () {
  var section = document.querySelector(".hero");
  var stage = section && section.querySelector(".hero-stage");
  var shot = stage && stage.querySelector(".hero-shot");
  if (!shot) {
    if (section) section.classList.add("is-done");
    return;
  }
  var WORDS = ["Hello", "World!", "Welcome", "to", "Apple", "Say."];
  var HUES = [[41, 151, 255], [94, 92, 230], [191, 90, 242], [255, 55, 95], [255, 159, 10]];
  var BARS = 64, SPEAK = 380, WORD = 190;
  var EASE = "cubic-bezier(.28,.11,.32,1)";
  var camera = section.querySelector(".hero-camera");
  var sheen = section.querySelector(".hero-sheen");
  var copy = Array.prototype.slice.call(section.querySelectorAll(".hero-meta > *"));
  var replay = section.querySelector(".hero-replay");
  var motion = matchMedia("(prefers-reduced-motion: no-preference)");
  var parts = [], running = [], seed;

  function rand() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
  function anim(el, frames, opts) {
    var a = el.animate(frames, Object.assign({ fill: "both", easing: EASE }, opts));
    running.push(a);
    return a;
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    e.className = cls;
    e.textContent = text;
    return e;
  }
  // Samples the blue-to-orange voice gradient at f in [0, 1].
  function hue(f) {
    var p = Math.min(0.999, Math.max(0, f)) * (HUES.length - 1), i = Math.floor(p), k = p - i;
    return "rgb(" + HUES[i].map(function (c, j) { return Math.round(c + (HUES[i + 1][j] - c) * k); }) + ")";
  }

  function finish() {
    running.forEach(function (a) { a.cancel(); });
    running = [];
    parts.forEach(function (p) { p.remove(); });
    parts = [];
    section.classList.add("is-done");
  }

  function play() {
    finish();
    if (!motion.matches) return;
    section.classList.remove("is-done");
    replay.hidden = true;
    seed = 11;

    var line = el("div", "hero-line", "");
    var wave = el("div", "hero-wave", "");
    var ping = el("div", "hero-ping", "");
    WORDS.forEach(function (w, i) {
      if (i) line.appendChild(document.createTextNode(" "));
      line.appendChild(el("span", "w", w));
    });
    for (var b = 0; b < BARS; b++) wave.appendChild(el("i", "", ""));
    [line, wave, ping].forEach(function (p) {
      p.setAttribute("aria-hidden", "true");
      stage.appendChild(p);
      parts.push(p);
    });
    line.style.setProperty("--k", stage.offsetWidth / 4276);
    var spans = line.querySelectorAll(".w"), width = line.offsetWidth, END = SPEAK + WORD * WORDS.length;

    // The camera starts close on the line, drifts while it is spoken, then pulls back.
    anim(camera, [
      { transform: "translate(30.8%, 32.2%) scale(3.9) rotateX(14deg) rotateZ(-3deg)", easing: "linear" },
      { transform: "translate(30.8%, 32.2%) scale(3.6) rotateX(9deg) rotateZ(-2deg)", offset: 0.45, easing: "cubic-bezier(.6,0,.2,1)" },
      { transform: "none" }
    ], { duration: 3000, easing: "linear" });

    anim(line, [{ opacity: 0, filter: "blur(6px)" }, { opacity: 1, filter: "blur(0px)" }], { duration: 500 });
    Array.prototype.forEach.call(spans, function (s, i) {
      var c = hue((s.offsetLeft + s.offsetWidth / 2) / width), at = SPEAK + i * WORD;
      // Once the window shows through, an outline covers its slightly heavier
      // captured glyphs beneath the lit words.
      function glow(o) {
        return { color: c, textShadow: [o + " 0", "-" + o + " 0", "0 " + o, "0 -" + o, "0 0 .5em"]
          .map(function (d) { return d + " " + c; }).join() };
      }
      var lit = glow("0em"), outlined = glow(".03em");
      var unlit = "0 0 transparent, 0 0 transparent, 0 0 transparent, 0 0 transparent, 0 0 0 transparent";
      anim(s, [{ color: "rgba(255,255,255,.3)", textShadow: unlit }, lit], { duration: 160, delay: at });
      anim(s, [{ transform: "none" }, { transform: "translateY(-.12em) scale(1.08)", offset: 0.35 }, { transform: "none" }],
        { duration: 420, delay: at, easing: "cubic-bezier(.3,0,.3,1)" });
      anim(s, [lit, outlined], { duration: 300, delay: 1500, fill: "forwards" });
      // Words settle to the editor's white before the line hands off to the capture.
      anim(s, [outlined, { color: "rgba(255,255,255,.8)", textShadow: unlit }],
        { duration: 500, delay: 2150 + i * 40, fill: "forwards" });
    });

    // Each bar swells as the spoken word passes over it and keeps a trace after.
    var STEPS = 20, SPAN = 2000;
    Array.prototype.forEach.call(wave.children, function (bar, i) {
      var x = (i + 0.5) / BARS, frames = [];
      bar.style.setProperty("--c", hue(x));
      for (var s = 0; s <= STEPS; s++) {
        var t = (SPAN * s) / STEPS, head = (t - SPEAK) / (END - SPEAK);
        var a = 0.06 + 0.94 * (0.4 + 0.6 * rand()) * Math.exp(-Math.pow((x - head) / 0.1, 2));
        if (x < head) a = Math.max(a, 0.18 + 0.3 * rand());
        frames.push({ transform: "scaleY(" + a.toFixed(3) + ")" });
      }
      anim(bar, frames, { duration: SPAN, easing: "linear" });
    });
    anim(wave, [{ opacity: 0 }, { opacity: 1 }], { duration: 400, delay: 150 });
    anim(wave, [
      { transform: "none", opacity: 1 },
      { transform: "translate(61cqw, -8.6cqw) scale(0.05, 0.6)", opacity: 1, offset: 0.85 },
      { transform: "translate(61cqw, -8.6cqw) scale(0.02, 0.3)", opacity: 0 }
    ], { duration: 750, delay: 1700, easing: "cubic-bezier(.55,0,.25,1)", fill: "forwards" });
    anim(ping, [
      { opacity: 0, transform: "scale(.3)" },
      { opacity: 1, transform: "scale(.8)", offset: 0.25 },
      { opacity: 0, transform: "scale(1.6)" }
    ], { duration: 1000, delay: 2340, easing: "cubic-bezier(.2,.7,.3,1)" });

    // The window opens first under the editor, then out to its full width.
    anim(shot, [{ opacity: 0 }, { opacity: 1 }], { duration: 450, delay: 1500, easing: "linear" });
    anim(shot, [
      { clipPath: "inset(4.92% 33.3% 9.59% 5.24% round 3.2cqw)" },
      { clipPath: "inset(0% 0% 0% 0% round 0cqw)" }
    ], { duration: 980, delay: 1920, easing: "cubic-bezier(.65,0,.2,1)" });
    anim(line, [{ opacity: 1 }, { opacity: 0 }], { duration: 650, delay: 2700, fill: "forwards", easing: "ease-in-out" });
    anim(sheen, [{ opacity: 0 }, { opacity: 1, offset: 0.15 }, { opacity: 1, offset: 0.85 }, { opacity: 0 }],
      { duration: 1200, delay: 3100, easing: "linear" });
    anim(sheen, [{ transform: "translateX(-60%)" }, { transform: "translateX(60%)" }],
      { duration: 1200, delay: 3100, easing: "cubic-bezier(.45,0,.2,1)", pseudoElement: "::after" });
    copy.forEach(function (c, i) {
      anim(c, [{ opacity: 0, transform: "translateY(18px)" }, { opacity: 1, transform: "none" }],
        { duration: 900, delay: 3300 + i * 110, easing: "cubic-bezier(.2,.7,.3,1)" });
    });

    var last = running[running.length - 1];
    last.finished.then(function () {
      finish();
      replay.hidden = false;
    }, function () {});
  }

  replay.addEventListener("click", play);
  // Like apple.com's load timeout: a slow capture shows statically instead.
  var timer = setTimeout(finish, 3000);
  function start() {
    clearTimeout(timer);
    if (!section.classList.contains("is-done")) play();
  }
  shot.addEventListener("error", finish);
  if (shot.complete && shot.naturalWidth) start();
  else shot.addEventListener("load", start, { once: true });
})();
