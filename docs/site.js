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

  /* The flags are the manual choice: remember it before the browser leaves. */
  var flags = document.querySelectorAll(".lang-switch a[hreflang]");
  for (var f = 0; f < flags.length; f++) {
    flags[f].addEventListener("click", function () {
      store(LANG_KEY, this.getAttribute("hreflang") === "en" ? "en" : "he");
    });
  }

  /* Every Hebrew page that has an English twin, and where it lives. */
  var EN_TWIN = {
    "/": "/en/",
    "/index.html": "/en/",
    "/privacy.html": "/en/privacy.html",
    "/terms.html": "/en/terms.html",
    "/support.html": "/en/support.html",
    "/accessibility.html": "/en/accessibility.html"
  };

  function wantsHebrew() {
    var langs = navigator.languages || [navigator.language || ""];
    for (var i = 0; i < langs.length; i++) {
      if (/^he|^iw/i.test(langs[i] || "")) return true;
    }
    try {
      var tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
      if (tz === "Asia/Jerusalem" || tz === "Asia/Tel_Aviv") return true;
    } catch (e) {}
    return false;
  }

  (function routeLanguage() {
    var path = location.pathname.replace(/\/{2,}/g, "/");
    var twin = EN_TWIN[path];
    if (!twin) return;                                   // already English, or a page with no twin
    if (/[?&]lang=he\b/.test(location.search)) {          // an explicit "stay in Hebrew" link
      store(LANG_KEY, "he");
      return;
    }
    var choice = stored(LANG_KEY);
    if (choice === "he") return;                          // they chose Hebrew — never move them
    if (choice !== "en") {                                // no choice yet: guess, and only once
      if (wantsHebrew()) return;
      /* Search engines and link previews should index the Hebrew page they
         asked for; hreflang tells them where the English one is. */
      if (/bot|crawl|spider|slurp|facebookexternalhit|embedly|preview|lighthouse/i
            .test(navigator.userAgent || "")) return;
    }
    location.replace(twin + location.search + location.hash);
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

  var motionToggles = document.querySelectorAll("[data-motion-toggle]");
  for (var m = 0; m < motionToggles.length; m++) {
    motionToggles[m].addEventListener("click", function () {
      setPaused(!root.classList.contains("motion-paused"));
    });
  }
})();
