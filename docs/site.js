/* ============================================================================
   טופי · Tofy — shared behaviour for every page on tofyapp.com.
   Four small jobs, all of them optional: the language a visitor lands in, the
   mobile menu, the scroll reveal (which must never be the reason content is
   invisible), and a single control that stops every animation on the page.
   Everything below is defensive — a page that has none of these elements
   loads this file harmlessly.
   ========================================================================== */
(function () {
  "use strict";

  var root = document.documentElement;

  /* ---------- which language a visitor lands in ----------------------------
     The Hebrew pages are the site's home, and Israel keeps them. Someone
     opening a Hebrew page from abroad, with no Hebrew browser and no Israeli
     clock, is sent to the English page instead — once, and never again after
     they pick a language themselves with the flags in the header.
     A choice always wins over the guess, in both directions. */
  var LANG_KEY = "tofy.lang";

  function store(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) {}
  }
  function stored(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }

  /* The language menu is a <details>, so it opens with no JS at all and the
     keyboard gets it for free. All JS adds is what a menu is expected to do:
     close when you click away, and close on Escape. */
  var langBox = document.querySelector("details.lang-switch");
  if (langBox) {
    document.addEventListener("click", function (e) {
      if (langBox.open && !langBox.contains(e.target)) langBox.open = false;
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && langBox.open) {
        langBox.open = false;
        var summary = langBox.querySelector("summary");
        if (summary) summary.focus();
      }
    });
  }

  /* The flags are the manual choice: remember it before the browser leaves. */
  var flags = document.querySelectorAll(".lang-switch a[hreflang]");
  for (var f = 0; f < flags.length; f++) {
    flags[f].addEventListener("click", function () {
      store(LANG_KEY, this.getAttribute("hreflang"));
    });
  }

  /* Every Hebrew page that has a twin, and where each one lives. Hebrew is the
     original, so the map is keyed on its paths; the English, Russian and Arabic
     pages are never redirected away from. */
  var TWINS = {
    "/":                   { en: "/en/",                   ru: "/ru/",                   ar: "/ar/" },
    "/index.html":         { en: "/en/",                   ru: "/ru/",                   ar: "/ar/" },
    "/privacy.html":       { en: "/en/privacy.html",       ru: "/ru/privacy.html",       ar: "/ar/privacy.html" },
    "/terms.html":         { en: "/en/terms.html",         ru: "/ru/terms.html",         ar: "/ar/terms.html" },
    "/support.html":       { en: "/en/support.html",       ru: "/ru/support.html",       ar: "/ar/support.html" },
    "/accessibility.html": { en: "/en/accessibility.html", ru: "/ru/accessibility.html", ar: "/ar/accessibility.html" }
  };

  /* What the browser itself asks for. Hebrew wins on an Israeli clock even when
     the language list says otherwise — a Hebrew speaker with an English phone
     is far more common here than the reverse. */
  function browserLanguage() {
    var langs = navigator.languages || [navigator.language || ""];
    for (var i = 0; i < langs.length; i++) {
      var tag = langs[i] || "";
      if (/^he|^iw/i.test(tag)) return "he";
      if (/^ru/i.test(tag)) return "ru";
      if (/^ar/i.test(tag)) return "ar";
      if (/^en/i.test(tag)) return "en";
    }
    return "";
  }
  function israeliClock() {
    try {
      var tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
      return tz === "Asia/Jerusalem" || tz === "Asia/Tel_Aviv";
    } catch (e) { return false; }
  }

  (function routeLanguage() {
    var path = location.pathname.replace(/\/{2,}/g, "/");
    var twins = TWINS[path];
    if (!twins) return;                                   // already translated, or no twin
    var pinned = /[?&]lang=(he|en|ru|ar)\b/.exec(location.search);
    if (pinned) {                                         // an explicit link wins and is remembered
      store(LANG_KEY, pinned[1]);
      if (pinned[1] === "he") return;
      location.replace(twins[pinned[1]] + location.search + location.hash);
      return;
    }
    var choice = stored(LANG_KEY);
    if (choice === "he") return;                          // they chose Hebrew — never move them
    if (choice !== "en" && choice !== "ru" && choice !== "ar") {             // no choice yet: guess, and only once
      /* Search engines and link previews should index the Hebrew page they
         asked for; hreflang tells them where the others are. */
      if (/bot|crawl|spider|slurp|facebookexternalhit|embedly|preview|lighthouse/i
            .test(navigator.userAgent || "")) return;
      var guess = browserLanguage();
      if (guess === "he" || guess === "") return;
      if (guess === "en" && israeliClock()) return;       // Hebrew family, English phone
      choice = guess;                                     // "en", "ru" or "ar"
    }
    if (!twins[choice]) return;
    location.replace(twins[choice] + location.search + location.hash);
  })();
  var reduced = window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)")
    : null;

  /* ---------- mobile menu --------------------------------------------------
     The button owns the open state, so aria-expanded can never drift out of
     sync with the panel — including when a link inside the panel closes it. */
  function setupMenu(btn) {
    var nav = document.getElementById(btn.getAttribute("aria-controls"));
    if (!nav) return;

    function setOpen(open) {
      nav.classList.toggle("open", open);
      btn.setAttribute("aria-expanded", open ? "true" : "false");
    }

    btn.addEventListener("click", function () {
      setOpen(btn.getAttribute("aria-expanded") !== "true");
    });

    /* A link closes the menu; the state attribute closes with it. */
    nav.addEventListener("click", function (e) {
      if (e.target.closest("a")) setOpen(false);
    });

    /* Escape closes and hands focus back to the button that opened it. */
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && btn.getAttribute("aria-expanded") === "true") {
        setOpen(false);
        btn.focus();
      }
    });
  }

  var menuBtns = document.querySelectorAll(".menu-btn[aria-controls]");
  for (var i = 0; i < menuBtns.length; i++) setupMenu(menuBtns[i]);

  /* ---------- scroll reveal ------------------------------------------------
     .reveal starts hidden only when the `js` class is set (inline, in <head>),
     so with JavaScript switched off the content is simply visible. If motion
     is not wanted, or the browser has no IntersectionObserver, everything is
     revealed at once rather than never. */
  var reveals = document.querySelectorAll(".reveal");
  function revealAll() {
    for (var j = 0; j < reveals.length; j++) reveals[j].classList.add("in");
  }
  if (reveals.length) {
    if (!("IntersectionObserver" in window) || (reduced && reduced.matches)) {
      revealAll();
    } else {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      }, { threshold: 0.12 });
      for (var k = 0; k < reveals.length; k++) io.observe(reveals[k]);
      // A jump to an anchor (#android, #download…) can land the reader on a
      // section the observer never saw cross its threshold — it stayed blank on
      // iOS Safari. Any in-page jump shows everything.
      window.addEventListener("hashchange", revealAll);
      if (location.hash) revealAll();
    }
  }

  /* ---------- one switch for all motion ------------------------------------
     WCAG 2.2.2: the hero video loops and the sparkles twinkle forever, so the
     page owes the reader a way to stop them. `motion-paused` on <html> freezes
     every CSS animation; the video is paused directly. */
  var videos = document.querySelectorAll("video[data-motion]");

  function setPaused(paused) {
    root.classList.toggle("motion-paused", paused);
    for (var v = 0; v < videos.length; v++) {
      if (paused) videos[v].pause();
      else {
        var playing = videos[v].play();
        if (playing && playing.catch) playing.catch(function () {});
      }
    }
    var toggles = document.querySelectorAll("[data-motion-toggle]");
    for (var t = 0; t < toggles.length; t++) {
      var btn = toggles[t];
      btn.setAttribute("aria-pressed", paused ? "true" : "false");
      var label = paused ? btn.getAttribute("data-label-play")
                         : btn.getAttribute("data-label-pause");
      if (label) {
        btn.setAttribute("aria-label", label);
        var text = btn.querySelector(".motion-text");
        if (text) text.textContent = label;
      }
      var icon = btn.querySelector(".motion-icon");
      if (icon) icon.textContent = paused ? "▶" : "⏸";
    }
  }

  /* Someone who asked their system for less motion gets a still page, and the
     button then offers to start it rather than stop it. */
  if (reduced && reduced.matches) setPaused(true);

  /* Mobile Safari refuses autoplay in Low Power Mode (and some in-app browsers
     always do), even for a muted inline video — it just sits on its poster.
     Playback IS allowed after a user gesture, so: if the autoplay was refused,
     put a ▶ on the video and start it on the first touch anywhere. */
  function armTapToPlay(v) {
    if (v.dataset.tapArmed) return;
    v.dataset.tapArmed = "1";
    var host = v.parentNode;
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "video-tap";
    var lang = (document.documentElement.lang || "he").slice(0, 2);
    btn.setAttribute("aria-label", { en: "Play video", ru: "Воспроизвести видео", ar: "تشغيل الفيديو" }[lang] || "הפעלת הסרטון");
    btn.textContent = "\u25B6\uFE0E";
    host.appendChild(btn);
    // Centre the ▶ on the video itself (the stage also holds a second phone).
    function place() {
      btn.style.left = (v.offsetLeft + v.offsetWidth / 2) + "px";
      btn.style.top = (v.offsetTop + v.offsetHeight / 2) + "px";
    }
    place();
    window.addEventListener("resize", place);
    function go() {
      if (root.classList.contains("motion-paused")) return;
      var p = v.play();
      if (p && p.then) p.then(done, function () {});
      else done();
    }
    function done() {
      btn.remove();
      document.removeEventListener("touchstart", go, true);
      document.removeEventListener("click", go, true);
    }
    btn.addEventListener("click", function (e) { e.stopPropagation(); root.classList.remove("motion-paused"); go(); });
    document.addEventListener("touchstart", go, { capture: true, passive: true });
    document.addEventListener("click", go, true);
  }
  if (!(reduced && reduced.matches)) {
    for (var w = 0; w < videos.length; w++) {
      (function (v) {
        v.muted = true;            // belt and braces: Safari only autoplays when muted is a PROPERTY too
        var p = v.play();
        if (p && p.catch) p.catch(function () { armTapToPlay(v); });
        // No promise (old browsers): if still paused shortly after load, arm.
        setTimeout(function () { if (v.paused && !root.classList.contains("motion-paused")) armTapToPlay(v); }, 1500);
      })(videos[w]);
    }
  }

  var motionToggles = document.querySelectorAll("[data-motion-toggle]");
  for (var m = 0; m < motionToggles.length; m++) {
    motionToggles[m].addEventListener("click", function () {
      setPaused(!root.classList.contains("motion-paused"));
    });
  }
})();
