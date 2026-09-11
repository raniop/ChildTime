// 💰 חינוך פיננסי — computed. Grade calibration follows the Israeli math
// curriculum the money world sits on: א׳ within 20, ב׳ within 100, ג׳ times
// tables, ד׳ division, ה׳ simple percent and agorot, ו׳ percent / ratio.
"use strict";
const { int, pick, numericDistractors, prefixed, and, KIDS, g, ltr, gcd } = require("./core");

// Items carry their grammatical gender so "עוֹלֶה/עוֹלָה" always agrees.
// Items carry their gender (so "עוֹלֶה/עוֹלָה" agrees) and a believable price
// band — a 90 ₪ ice cream or a 400 ₪ pencil teaches the arithmetic and breaks
// the story.
const ITEMS = [
  { n: "מַדְבֵּקָה", f: true, lo: 1, hi: 8 },   { n: "עִפָּרוֹן", f: false, lo: 2, hi: 12 },
  { n: "גְּלִידָה", f: true, lo: 6, hi: 25 },    { n: "מַחְבֶּרֶת", f: true, lo: 5, hi: 30 },
  { n: "בַּקְבּוּק", f: false, lo: 8, hi: 45 },  { n: "כַּדּוּר", f: false, lo: 20, hi: 120 },
  { n: "סֵפֶר", f: false, lo: 30, hi: 120 },     { n: "בֻּבָּה", f: true, lo: 40, hi: 200 },
  { n: "חֻלְצָה", f: true, lo: 40, hi: 250 },    { n: "מִשְׂחָק", f: false, lo: 50, hi: 400 },
  { n: "נַעֲלַיִם", f: true, pl: true, lo: 120, hi: 500 },
];
// An item whose band fits [lo, hi]; falls back to the widest-band item.
const itemIn = (r, lo, hi) => { const ok = ITEMS.filter((i) => i.hi >= lo && i.lo <= hi); return ok.length ? pick(r, ok) : ITEMS[ITEMS.length - 2]; };
const priceOf = (r, it, lo, hi) => int(r, Math.max(lo, it.lo), Math.max(Math.max(lo, it.lo), Math.min(hi, it.hi)));
const costs = (it) => (it.pl ? "עוֹלוֹת" : it.f ? "עוֹלָה" : "עוֹלֶה");
const sh = (v) => `${v} ₪`;
// Never offer "0 ₪" — nobody pays nothing, so it is an option a child ignores.
const dist = (r, ans, o = {}) => numericDistractors(r, ans, { fmt: sh, min: 1, ...o });

const byGrade = {
  1(r) {
    const k = pick(r, KIDS);
    switch (int(r, 0, 3)) {
      case 0: { const a = int(r, 2, 9), b = int(r, 1, 10 - a);
        return { prompt: `💰\n${prefixed("לְ", k.n)} הָיוּ ${a} ₪ וְ${g(k, "הוּא קִבֵּל", "הִיא קִבְּלָה")} עוֹד ${b} ₪. כַּמָּה ₪ יֵשׁ ${g(k, "לוֹ", "לָהּ")} עַכְשָׁו?`, correctAnswer: sh(a + b), distractors: dist(r, a + b), tier: "easy" }; }
      case 1: { const a = int(r, 4, 10), b = int(r, 1, a - 1);
        return { prompt: `🛒\n${prefixed("לְ", k.n)} הָיוּ ${a} ₪ וְ${g(k, "הוּא קָנָה", "הִיא קָנְתָה")} מַדְבֵּקָה בְּ־${b} ₪. כַּמָּה ₪ נִשְׁאֲרוּ ${g(k, "לוֹ", "לָהּ")}?`, correctAnswer: sh(a - b), distractors: dist(r, a - b), tier: "easy" }; }
      case 2: { const a = pick(r, [1, 2, 5, 10]), b = pick(r, [1, 2, 5, 10]);
        return { prompt: `🪙\nמַטְבֵּעַ שֶׁל ${a} ₪ וּמַטְבֵּעַ שֶׁל ${b} ₪. כַּמָּה זֶה בְּיַחַד?`, correctAnswer: sh(a + b), distractors: dist(r, a + b), tier: "easy" }; }
      default: { const c = int(r, 2, 5), v = pick(r, [1, 2]);
        return { prompt: `🪙\n${c} מַטְבְּעוֹת שֶׁל ${v} ₪. כַּמָּה ₪ זֶה?`, correctAnswer: sh(c * v), distractors: dist(r, c * v, { step: v }), tier: "medium" }; }
    }
  },
  2(r) {
    const k = pick(r, KIDS), it = pick(r, ITEMS);
    switch (int(r, 0, 3)) {
      case 0: {
        // Two real items at their real prices — a notebook is never 60 ₪.
        const x = itemIn(r, 11, 60), y = pick(r, ITEMS.filter((i) => i !== x && i.lo <= 40));
        const a = priceOf(r, x, 11, 60), b = priceOf(r, y, 5, 99 - a);
        if (a + b > 99 || b > 99 - a) return null;
        return { prompt: `🧾\n${x.n} ${costs(x)} ${a} ₪ ${and(y.n)} ${costs(y)} ${b} ₪. כַּמָּה עוֹלֶה הַכֹּל יַחַד?`, correctAnswer: sh(a + b), distractors: dist(r, a + b), tier: "medium" }; }
      case 1: { const paid = pick(r, [20, 50, 100]); const it2 = itemIn(r, 3, paid - 1); const price = priceOf(r, it2, 3, paid - 1);
        if (price >= paid) return null;
        const it = it2;
        return { prompt: `💵\n${it.n} ${costs(it)} ${price} ₪. ${k.n} ${g(k, "שִׁלֵּם", "שִׁלְּמָה")} ${paid} ₪. כַּמָּה עֹדֶף ${g(k, "יְקַבֵּל", "תְּקַבֵּל")}?`, correctAnswer: sh(paid - price), distractors: dist(r, paid - price), tier: "medium" }; }
      case 2: { const n = int(r, 2, 5), p = int(r, 2, 10);
        return { prompt: `🛍️\n${k.n} ${g(k, "קָנָה", "קָנְתָה")} ${n} מַדְבֵּקוֹת, כָּל אַחַת בְּ־${p} ₪. כַּמָּה ${g(k, "שִׁלֵּם", "שִׁלְּמָה")}?`, correctAnswer: sh(n * p), distractors: dist(r, n * p, { step: p }), tier: "medium" }; }
      default: { const w = int(r, 2, 6), s = int(r, 3, 10);
        return { prompt: `🐷\n${k.n} ${g(k, "חוֹסֵךְ", "חוֹסֶכֶת")} ${s} ₪ כָּל שָׁבוּעַ. כַּמָּה ${g(k, "יַחְסֹךְ", "תַּחְסֹךְ")} אַחֲרֵי ${w} שָׁבוּעוֹת?`, correctAnswer: sh(w * s), distractors: dist(r, w * s, { step: s }), tier: "hard" }; }
    }
  },
  3(r) {
    const k = pick(r, KIDS), it = pick(r, ITEMS);
    switch (int(r, 0, 3)) {
      case 0: { const it = itemIn(r, 6, 50), n = int(r, 3, 10), p = priceOf(r, it, 6, 50);
        return { prompt: `🛒\n${it.n} ${costs(it)} ${p} ₪. כַּמָּה עוֹלִים ${n} כָּאֵלֶּה?`, correctAnswer: sh(n * p), distractors: dist(r, n * p, { step: p, mistakes: [n + p, n * p + p, n * p - p] }), tier: "medium" }; }
      case 1: { const paid = pick(r, [100, 200, 500]); const it = itemIn(r, 21, paid - 5); const price = priceOf(r, it, 21, paid - 5);
        if (price >= paid) return null;
        return { prompt: `💵\n${k.n} ${g(k, "קָנָה", "קָנְתָה")} ${it.n} בְּ־${price} ₪ וְ${g(k, "שִׁלֵּם", "שִׁלְּמָה")} ${paid} ₪. כַּמָּה עֹדֶף ${g(k, "קִבֵּל", "קִבְּלָה")}?`, correctAnswer: sh(paid - price), distractors: dist(r, paid - price), tier: "medium" }; }
      case 2: { const s = int(r, 5, 25), w = int(r, 4, 12);
        return { prompt: `🐷\n${k.n} ${g(k, "חוֹסֵךְ", "חוֹסֶכֶת")} ${s} ₪ בְּכָל שָׁבוּעַ. כַּמָּה ${g(k, "יִהְיֶה לוֹ", "יִהְיֶה לָהּ")} אַחֲרֵי ${w} שָׁבוּעוֹת?`, correctAnswer: sh(s * w), distractors: dist(r, s * w, { step: s }), tier: "hard" }; }
      default: { const s = int(r, 5, 20), w = int(r, 3, 10);
        return { prompt: `🎯\n${k.n} ${g(k, "רוֹצֶה", "רוֹצָה")} לִקְנוֹת מִשְׂחָק בְּ־${s * w} ₪ ${g(k, "וְחוֹסֵךְ", "וְחוֹסֶכֶת")} ${s} ₪ בְּכָל שָׁבוּעַ. כַּמָּה שָׁבוּעוֹת ${g(k, "יִצְטָרֵךְ", "תִּצְטָרֵךְ")} לַחְסֹךְ?`, correctAnswer: String(w), distractors: numericDistractors(r, w, { min: 1 }), tier: "hard" }; }
    }
  },
  4(r) {
    const k = pick(r, KIDS), it = pick(r, ITEMS);
    switch (int(r, 0, 3)) {
      case 0: { const kids = int(r, 2, 8), each = int(r, 6, 60);
        return { prompt: `🤝\n${kids} יְלָדִים חוֹלְקִים ${kids * each} ₪ שָׁוֶה בְּשָׁוֶה. כַּמָּה ₪ מְקַבֵּל כָּל יֶלֶד?`, correctAnswer: sh(each), distractors: dist(r, each), tier: "medium" }; }
      case 1: { const n = int(r, 3, 12), p = int(r, 4, 45);
        return { prompt: `🧾\n${n} מַחְבָּרוֹת עָלוּ ${n * p} ₪. כַּמָּה עוֹלָה מַחְבֶּרֶת אַחַת?`, correctAnswer: sh(p), distractors: dist(r, p), tier: "medium" }; }
      case 2: { const it = itemIn(r, 40, 400), price = priceOf(r, it, 40, 400), off = int(r, 5, Math.max(5, Math.floor(price / 2)));
        return { prompt: `🏷️\n${it.n} ${costs(it)} ${price} ₪ וְיֵשׁ עָלֶיהָ הֲנָחָה שֶׁל ${off} ₪. כַּמָּה צָרִיךְ לְשַׁלֵּם?`.replace("עָלֶיהָ", it.f ? "עָלֶיהָ" : "עָלָיו"), correctAnswer: sh(price - off), distractors: dist(r, price - off), tier: "medium" }; }
      default: { const budget = pick(r, [200, 300, 500, 1000]), a = int(r, 30, Math.floor(budget / 2)), b = int(r, 20, budget - a - 10);
        return { prompt: `📋\n${prefixed("לְ", k.n)} יֵשׁ ${budget} ₪. ${g(k, "הוּא קָנָה", "הִיא קָנְתָה")} סֵפֶר בְּ־${a} ₪ וּמִשְׂחָק בְּ־${b} ₪. כַּמָּה נִשְׁאַר ${g(k, "לוֹ", "לָהּ")}?`, correctAnswer: sh(budget - a - b), distractors: dist(r, budget - a - b), tier: "hard" }; }
    }
  },
  5(r) {
    const it = pick(r, ITEMS), k = pick(r, KIDS);
    switch (int(r, 0, 3)) {
      case 0: { const price = int(r, 2, 90) * 10;
        const a = price / 10;
        return { prompt: `📊\nכַּמָּה זֶה 10% מִ־${price} ₪?`, correctAnswer: sh(a), distractors: dist(r, a, { min: 1, step: Math.max(1, Math.round(a / 5)), mistakes: [price / 100 >= 1 && Number.isInteger(price / 100) ? price / 100 : a * 2, price - a, a + 10] }), tier: "medium" }; }
      case 1: { const it = itemIn(r, 10, 250); const price = Math.max(2, Math.round(priceOf(r, it, 10, 250) / 2) * 2);
        return { prompt: `🏷️\n${it.n} ${costs(it)} ${price} ₪, וְיֵשׁ הֲנָחָה שֶׁל 50%. כַּמָּה ${it.f ? "הִיא עוֹלָה" : "הוּא עוֹלֶה"} אַחֲרֵי הַהֲנָחָה?`, correctAnswer: sh(price / 2), distractors: dist(r, price / 2), tier: "medium" }; }
      case 2: { const base = int(r, 2, 50) * 4;
        return { prompt: `📊\nכַּמָּה זֶה 25% מִ־${base} ₪?`, correctAnswer: sh(base / 4), distractors: dist(r, base / 4), tier: "hard" }; }
      default: { const n = int(r, 2, 9), half = int(r, 1, 19); const p = half + 0.5, total = n * p;
        return { prompt: `🍦\nגְּלִידָה עוֹלָה ${p} ₪. ${k.n} ${g(k, "קָנָה", "קָנְתָה")} ${n} גְּלִידוֹת. כַּמָּה ${g(k, "שִׁלֵּם", "שִׁלְּמָה")}?`, correctAnswer: sh(total), distractors: numericDistractors(r, total, { step: 0.5, fmt: sh }), tier: "hard" }; }
    }
  },
  6(r) {
    const it = pick(r, ITEMS), k = pick(r, KIDS);
    switch (int(r, 0, 3)) {
      case 0: { const pct = pick(r, [10, 20, 25, 30, 40, 50]); const it = itemIn(r, 40, 500); const price = Math.max(20, Math.round(priceOf(r, it, 40, 500) / 20) * 20); const final = price * (100 - pct) / 100;
        if (!Number.isInteger(final)) return null;
        return { prompt: `🏷️\n${it.n} ${costs(it)} ${price} ₪ וְיֵשׁ הֲנָחָה שֶׁל ${pct}%. כַּמָּה צָרִיךְ לְשַׁלֵּם?`, correctAnswer: sh(final), distractors: dist(r, final, { min: 1, max: price, step: Math.max(1, Math.round(price * 0.05)), mistakes: [price * pct / 100, price - pct] }), tier: "hard" }; }
      case 1: { const pct = pick(r, [10, 20, 50]), price = int(r, 2, 30) * 10; const final = price * (100 + pct) / 100;
        return { prompt: `📈\nמְחִיר שֶׁל ${price} ₪ עָלָה בְּ־${pct}%. מָה הַמְּחִיר הֶחָדָשׁ?`, correctAnswer: sh(final), distractors: dist(r, final, { step: Math.max(1, Math.round(price * 0.05)) }), tier: "hard" }; }
      case 2: { const a = int(r, 1, 4), b = int(r, 1, 5); if (a === b) return null; const unit = int(r, 5, 40); const total = (a + b) * unit;
        return { prompt: `⚖️\n${k.n} וְאָחִיו חוֹלְקִים ${total} ₪ בְּיַחַס שֶׁל ${a} : ${b}. כַּמָּה ${g(k, "מְקַבֵּל", "מְקַבֶּלֶת")} ${k.n}?`.replace("וְאָחִיו", g(k, "וְאָחִיו", "וְאָחִיהָ")), correctAnswer: sh(a * unit), distractors: dist(r, a * unit, { min: 1, max: total, step: unit, mistakes: [b * unit, total, total / 2] }), tier: "hard" }; }
      default: { const u1 = int(r, 2, 9), n1 = int(r, 2, 6), u2 = u1 + int(r, 1, 3), n2 = n1 + int(r, 1, 4);
        const cheap = { n: n1, p: u1 * n1 }, dear = { n: n2, p: u2 * n2 }; // cheap has the lower unit price
        // Randomise which label is the cheap one — otherwise the answer is always
        // "א׳" and a child learns the letter instead of the maths.
        const cheapIsA = r() < 0.5, A = cheapIsA ? cheap : dear, B = cheapIsA ? dear : cheap;
        return { prompt: `🛒\nחֲבִילָה א׳: ${A.n} מַחְבָּרוֹת בְּ־${A.p} ₪. חֲבִילָה ב׳: ${B.n} מַחְבָּרוֹת בְּ־${B.p} ₪. אֵיזוֹ זוֹלָה יוֹתֵר לְמַחְבֶּרֶת?`, correctAnswer: cheapIsA ? "חֲבִילָה א׳" : "חֲבִילָה ב׳", distractors: [cheapIsA ? "חֲבִילָה ב׳" : "חֲבִילָה א׳", "שְׁתֵּיהֶן אוֹתוֹ מְחִיר", "אִי אֶפְשָׁר לָדַעַת"], tier: "hard" }; }
    }
  },
  // ——— ז׳: חינוך פיננסי — הנחות כפולות, רִבִּית פְּשׁוּטָה, אָחוּז שִׁנּוּי, שַׁעַר חֲלִיפִין, תַּקְצִיב ———
  7(r) {
    const k = pick(r, KIDS);
    switch (int(r, 0, 5)) {
      case 0: { // two discounts one after the other are NOT their sum
        const price = int(r, 5, 40) * 20, p1 = pick(r, [10, 20, 25, 50]), p2 = pick(r, [10, 20]);
        const final = price * (100 - p1) / 100 * (100 - p2) / 100;
        if (!Number.isInteger(final) || !Number.isInteger(price * (100 - p1 - p2) / 100)) return null;
        return { prompt: `🏷️\nמְעִיל עוֹלֶה ${price} ₪. קִבַּלְנוּ הֲנָחָה שֶׁל ${p1}%, וְאַחֲרֶיהָ עוֹד ${p2}% הֲנָחָה עַל הַמְּחִיר הַחָדָשׁ. כַּמָּה מְשַׁלְּמִים?`,
          correctAnswer: sh(final), distractors: dist(r, final, { step: Math.max(1, Math.round(price * 0.02)), mistakes: [price * (100 - p1 - p2) / 100, price * (p1 + p2) / 100] }), tier: "hard" }; }
      case 1: { // simple interest
        const dep = int(r, 1, 20) * 500, rate = pick(r, [2, 3, 4, 5, 10]), years = int(r, 2, 5);
        const interest = dep * rate * years / 100;
        if (!Number.isInteger(interest)) return null;
        return { prompt: `🏦\n${k.n} ${g(k, "הִפְקִיד", "הִפְקִידָה")} ${dep} ₪ בְּחִסָּכוֹן עִם רִבִּית פְּשׁוּטָה שֶׁל ${rate}% בְּשָׁנָה. כַּמָּה כֶּסֶף יִהְיֶה בַּחִסָּכוֹן אַחֲרֵי ${years} שָׁנִים?`,
          correctAnswer: sh(dep + interest), distractors: dist(r, dep + interest, { step: Math.max(5, dep * rate / 100), mistakes: [interest, dep + dep * rate / 100] }), tier: "hard" }; }
      case 2: { // percent change between two prices
        const before = int(r, 2, 30) * 20, pct = pick(r, [5, 10, 15, 20, 25, 40, 50]), up = r() < 0.5;
        const after = before * (100 + (up ? pct : -pct)) / 100;
        if (!Number.isInteger(after)) return null;
        return { prompt: `📊\nמְחִיר הַכַּרְטִיס ${up ? "עָלָה" : "יָרַד"} מִ־${before} ₪ לְ־${after} ₪. בְּכַמָּה אֲחוּזִים ${up ? "הוּא עָלָה" : "הוּא יָרַד"}?`,
          correctAnswer: `${pct}%`, distractors: [`${Math.abs(after - before)}%`, `${Math.round(Math.abs(after - before) * 100 / after)}%`, `${pct + 5}%`, `${pct * 2}%`, `${Math.max(1, pct - 5)}%`].filter((x, i, a) => x !== `${pct}%` && a.indexOf(x) === i && parseInt(x, 10) <= 100).slice(0, 3), tier: "hard" }; }
      case 3: { // exchange rate (a stated, made-up rate — never "today's")
        const rate = pick(r, [3, 3.5, 4]), dollars = int(r, 2, 40) * 2, shekels = dollars * rate;
        if (!Number.isInteger(shekels)) return null;
        return { prompt: `💱\nנַנִּיחַ שֶׁדּוֹלָר אֶחָד שָׁוֶה ${rate} ₪. ${k.n} ${g(k, "רוֹצֶה", "רוֹצָה")} לִקְנוֹת מִשְׂחָק שֶׁעוֹלֶה ${dollars} דּוֹלָר. כַּמָּה זֶה בִּשְׁקָלִים?`,
          correctAnswer: sh(shekels), distractors: dist(r, shekels, { step: rate * 2, mistakes: [Math.round(dollars / rate), dollars + rate] }), tier: "medium" }; }
      case 4: { // budget: a fraction of the allowance
        const allowance = pick(r, [120, 150, 180, 200, 240, 300]), [num, den] = pick(r, [[1, 3], [1, 4], [2, 5], [3, 4], [1, 5], [3, 5]]);
        const spent = allowance * num / den;
        if (!Number.isInteger(spent)) return null;
        return { prompt: `🗓️\n${k.n} ${g(k, "מְקַבֵּל", "מְקַבֶּלֶת")} ${allowance} ₪ דְּמֵי כִּיס בְּחֹדֶשׁ וּ${g(k, "מוֹצִיא", "מוֹצִיאָה")} ${ltr(`${num}/${den}`)} מֵהֶם עַל אֹכֶל. כַּמָּה נִשְׁאָר ${g(k, "לוֹ", "לָהּ")}?`,
          correctAnswer: sh(allowance - spent), distractors: dist(r, allowance - spent, { step: Math.max(5, allowance / 20), mistakes: [spent, allowance - num * den] }), tier: "medium" }; }
      default: { // unit price comparison, with the answer as a price
        const n1 = pick(r, [4, 6, 8]), n2 = pick(r, [10, 12, 15]), u1 = int(r, 3, 9), u2 = u1 - int(r, 1, 2);
        if (u2 < 1) return null;
        return { prompt: `🥤\nחֲבִילָה שֶׁל ${n1} בַּקְבּוּקִים עוֹלָה ${n1 * u1} ₪, וַחֲבִילָה שֶׁל ${n2} בַּקְבּוּקִים עוֹלָה ${n2 * u2} ₪. כַּמָּה חוֹסְכִים עַל כָּל בַּקְבּוּק כְּשֶׁקּוֹנִים אֶת הַחֲבִילָה הַגְּדוֹלָה?`,
          correctAnswer: sh(u1 - u2), distractors: dist(r, u1 - u2, { min: 1, mistakes: [n2 * u2 - n1 * u1, u1, n2 - n1] }), tier: "hard" }; }
    }
  },
  // ——— ח׳: רִבִּית דְּרִבִּית, אָחוּז הָפוּךְ, הַשְׁוָאַת תָּכְנִיּוֹת, מְמֻצָּע חָסֵר, חֲלֻקָּה בְּיַחַס ———
  8(r) {
    const k = pick(r, KIDS);
    switch (int(r, 0, 5)) {
      case 0: { // compound interest over two years
        const dep = int(r, 1, 30) * 100, rate = pick(r, [10, 20]);
        const final = dep * (100 + rate) * (100 + rate) / 10000;
        if (!Number.isInteger(final)) return null;
        return { prompt: `🏦\n${dep} ₪ בְּחִסָּכוֹן עִם רִבִּית דְּרִבִּית שֶׁל ${rate}% בְּשָׁנָה. כַּמָּה יִהְיֶה בַּחִסָּכוֹן אַחֲרֵי שְׁנָתַיִם?`,
          correctAnswer: sh(final), distractors: dist(r, final, { step: Math.max(2, dep * 0.02), mistakes: [dep * (100 + 2 * rate) / 100, dep * (100 + rate) / 100] }), tier: "hard" }; }
      case 1: { // reverse percent: the price after the discount → the original
        const orig = int(r, 3, 30) * 20, pct = pick(r, [10, 20, 25, 50]), after = orig * (100 - pct) / 100;
        if (!Number.isInteger(after) || !Number.isInteger(after * (100 + pct) / 100)) return null;
        return { prompt: `🔎\nאַחֲרֵי הֲנָחָה שֶׁל ${pct}% ${k.n} ${g(k, "שִׁלֵּם", "שִׁלְּמָה")} ${after} ₪ עַל אוֹזְנִיּוֹת. מֶה הָיָה הַמְּחִיר לִפְנֵי הַהֲנָחָה?`,
          correctAnswer: sh(orig), distractors: dist(r, orig, { step: Math.max(2, orig * 0.05), mistakes: [after * (100 + pct) / 100, after + pct] }), tier: "hard" }; }
      case 2: { // two phone plans: when do they cost the same?
        const perA = int(r, 1, 4), perB = perA + int(r, 1, 4), fixedB = int(r, 1, 4) * 5, x = int(r, 3, 20);
        const fixedA = fixedB + (perB - perA) * x;
        if (fixedA > 150) return null;
        return { prompt: `📱\nתָּכְנִית א׳: ${fixedA} ₪ בְּחֹדֶשׁ וְעוֹד ${perA} ₪ לְכָל גִּיגָה.\nתָּכְנִית ב׳: ${fixedB} ₪ בְּחֹדֶשׁ וְעוֹד ${perB} ₪ לְכָל גִּיגָה.\nבְּכַמָּה גִּיגָה הֵן עוֹלוֹת אוֹתוֹ דָּבָר?`,
          correctAnswer: String(x), distractors: dist(r, x, { fmt: String, min: 1, mistakes: [Math.round(fixedA / perB), Math.round((fixedA + fixedB) / (perA + perB))] }), tier: "hard" }; }
      case 3: { // the missing month for a target average
        const target = int(r, 4, 20) * 10, known = [0, 0, 0].map(() => target + int(r, -4, 4) * 5);
        const need = 4 * target - known.reduce((a, b) => a + b, 0);
        if (need <= 0) return null;
        return { prompt: `📒\nבִּשְׁלֹשָׁה חֳדָשִׁים ${k.n} ${g(k, "חָסַךְ", "חָסְכָה")} ${known[0]}, ${known[1]} וְ־${known[2]} ₪. כַּמָּה ${g(k, "צָרִיךְ", "צְרִיכָה")} לַחְסֹךְ בַּחֹדֶשׁ הָרְבִיעִי כְּדֵי שֶׁהַמְּמֻצָּע יִהְיֶה ${target} ₪?`,
          correctAnswer: sh(need), distractors: dist(r, need, { step: 5, mistakes: [target, 3 * target - known.reduce((a, b) => a + b, 0) + target * 0] }), tier: "hard" }; }
      case 4: { // sharing in a three-way ratio
        const a = int(r, 1, 4), b = int(r, 1, 4), c = int(r, 1, 5), unit = int(r, 5, 30);
        if ((a === b && b === c) || gcd(gcd(a, b), c) > 1) return null;   // a reduced ratio, like a textbook
        const total = (a + b + c) * unit;
        return { prompt: `⚖️\nשְׁלֹשָׁה אַחִים חוֹלְקִים ${total} ₪ בְּיַחַס ${ltr(`${a} : ${b} : ${c}`)}. כַּמָּה מְקַבֵּל הָאָח שֶׁחֶלְקוֹ ${c}?`,
          correctAnswer: sh(c * unit), distractors: dist(r, c * unit, { step: unit, mistakes: [Math.round(total / 3), total / c === Math.round(total / c) ? total / c : c * unit + unit] }), tier: "hard" }; }
      default: { // salary after tax, then a percent of what is left
        const salary = int(r, 4, 20) * 500, tax = pick(r, [10, 20]), save = pick(r, [10, 20, 25]);
        const net = salary * (100 - tax) / 100, saved = net * save / 100;
        if (!Number.isInteger(saved)) return null;
        return { prompt: `💼\nמַשְׂכֹּרֶת שֶׁל ${salary} ₪. ${tax}% הוֹלְכִים לְמַס, וּמִמָּה שֶׁנִּשְׁאַר חוֹסְכִים ${save}%. כַּמָּה חוֹסְכִים?`,
          correctAnswer: sh(saved), distractors: dist(r, saved, { step: Math.max(5, saved * 0.1), mistakes: [salary * save / 100, salary * (save - tax) / 100] }), tier: "hard" }; }
    }
  },
};

module.exports = { topic: "money", byGrade };
