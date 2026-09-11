// ⚽ עולם הכדורגל — the computed half: scores, points, minutes, averages and
// percentages. Teams are colours, not clubs — timeless, and a plural subject
// keeps every verb in one agreement ("הַכְּחֻלִּים הִבְקִיעוּ").
"use strict";
const { int, pick, numericDistractors, pctDistractors, prefixed, and, ltr, signed, frac } = require("./core");

const TEAMS = ["הַכְּחֻלִּים", "הָאֲדֻמִּים", "הַצְּהֻבִּים", "הַיְּרֻקִּים", "הַלְּבָנִים", "הַשְּׁחֹרִים"];
const two = (r) => { const a = pick(r, TEAMS); let b = pick(r, TEAMS); while (b === a) b = pick(r, TEAMS); return [a, b]; };
const d = (r, ans, o) => numericDistractors(r, ans, o);

const byGrade = {
  1(r) {
    const [A, B] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const a = int(r, 1, 6), b = int(r, 1, 10 - a);
        return { prompt: `⚽\n${A} הִבְקִיעוּ ${a} גּוֹלִים וְ${B} הִבְקִיעוּ ${b}. כַּמָּה גּוֹלִים הָיוּ בַּמִּשְׂחָק?`.replace(" 1 גּוֹלִים", " גּוֹל אֶחָד"), correctAnswer: String(a + b), distractors: d(r, a + b, { min: 0, max: 12, mistakes: [Math.abs(a - b)] }), tier: "easy" }; }
      case 1: { const a = int(r, 0, 5); let b = int(r, 0, 5); if (a === b) b = (b + 1) % 6;
        const win = a > b ? A : B, lose = a > b ? B : A;
        return { prompt: `🥇\n${A} ${a} · ${B} ${b}. מִי נִצְּחוּ?`, correctAnswer: win, distractors: [lose, "תֵּיקוּ", "אַף אַחַת"], tier: "easy" }; }
      case 2: { const a = int(r, 1, 5), b = int(r, 1, 10 - a);
        return { prompt: `⏱️\n${A} הִבְקִיעוּ ${a} בַּמַּחֲצִית הָרִאשׁוֹנָה וְ${b} בַּשְּׁנִיָּה. כַּמָּה גּוֹלִים בְּסַךְ הַכֹּל?`, correctAnswer: String(a + b), distractors: d(r, a + b, { min: 0, max: 12 }), tier: "easy" }; }
      default: { const a = int(r, 3, 10), b = int(r, 1, a - 1);
        return { prompt: `🚩\n${A} הִבְקִיעוּ ${a} גּוֹלִים, אֲבָל ${b} מֵהֶם נִפְסְלוּ. כַּמָּה גּוֹלִים נִשְׁאֲרוּ?`, correctAnswer: String(a - b), distractors: d(r, a - b, { min: 0, max: 12, mistakes: [a + b] }), tier: "medium" }; }
    }
  },
  2(r) {
    const [A] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const x = int(r, 1, 9);
        return { prompt: `⏱️\nהַשּׁוֹפֵט הוֹסִיף ${x === 1 ? "דַּקָּה אַחַת" : `${x} דַּקּוֹת`} לַמַּחֲצִית. כַּמָּה דַּקּוֹת נִמְשְׁכָה הַמַּחֲצִית?`, correctAnswer: String(45 + x), distractors: d(r, 45 + x), tier: "medium" }; }
      case 1: { const w = int(r, 2, 9);
        return { prompt: `🏆\n${A} נִצְּחוּ בְּ־${w} מִשְׂחָקִים, וְכָל נִצָּחוֹן שָׁוֶה 3 נְקֻדּוֹת. כַּמָּה נְקֻדּוֹת יֵשׁ לָהֶם?`, correctAnswer: String(w * 3), distractors: d(r, w * 3, { step: 3 }), tier: "medium" }; }
      case 2: { const a = int(r, 12, 60), b = int(r, 10, 99 - a);
        return { prompt: `👥\nבַּיָּצִיעַ הַצְּפוֹנִי יָשְׁבוּ ${a} אוֹהֲדִים וּבַדְּרוֹמִי ${b}. כַּמָּה אוֹהֲדִים הָיוּ בַּמִּגְרָשׁ?`, correctAnswer: String(a + b), distractors: d(r, a + b), tier: "medium" }; }
      default: { const a = int(r, 20, 99), b = int(r, 5, a - 5);
        return { prompt: `🎟️\nהָיוּ ${a} כַּרְטִיסִים לַמִּשְׂחָק וְנִמְכְּרוּ ${b}. כַּמָּה כַּרְטִיסִים נִשְׁאֲרוּ?`, correctAnswer: String(a - b), distractors: d(r, a - b, { min: 0, max: 12, mistakes: [a + b] }), tier: "medium" }; }
    }
  },
  3(r) {
    const [A] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const w = int(r, 2, 12), dr = int(r, 1, 8);
        return { prompt: `🏆\n${A} נִצְּחוּ בְּ־${w} מִשְׂחָקִים וְסִיְּמוּ ${dr} בְּתֵיקוּ. נִצָּחוֹן = 3 נְקֻדּוֹת, תֵּיקוּ = נְקֻדָּה. כַּמָּה נְקֻדּוֹת יֵשׁ לָהֶם?`, correctAnswer: String(w * 3 + dr), distractors: [String(w + dr), String(w * 3), String((w + dr) * 3)].filter((v, i, arr) => v !== String(w * 3 + dr) && arr.indexOf(v) === i).concat(d(r, w * 3 + dr)).slice(0, 3), tier: "hard" }; }
      case 1: { const g = int(r, 2, 5), m = int(r, 3, 10);
        return { prompt: `⚽\n${A} הִבְקִיעוּ ${g} גּוֹלִים בְּכָל אֶחָד מִ־${m} מִשְׂחָקִים. כַּמָּה גּוֹלִים בְּסַךְ הַכֹּל?`, correctAnswer: String(g * m), distractors: d(r, g * m, { min: 1, step: g, mistakes: [g + m, g * m + g, g * m - g] }), tier: "medium" }; }
      case 2: { const m = int(r, 2, 10);
        return { prompt: `⏱️\nכָּל מִשְׂחָק נִמְשָׁךְ 90 דַּקּוֹת. כַּמָּה דַּקּוֹת ${A} שִׂחֲקוּ בְּ־${m} מִשְׂחָקִים?`, correctAnswer: String(90 * m), distractors: d(r, 90 * m, { step: 90 }), tier: "medium" }; }
      default: { const e = int(r, 5, 85);
        return { prompt: `⏳\nעָבְרוּ ${e} דַּקּוֹת מִתּוֹךְ 90. כַּמָּה דַּקּוֹת נִשְׁאֲרוּ לַמִּשְׂחָק?`, correctAnswer: String(90 - e), distractors: d(r, 90 - e), tier: "medium" }; }
    }
  },
  4(r) {
    const [A] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const f = int(r, 10, 70), a = int(r, 3, f - 1);
        return { prompt: `📊\n${A} הִבְקִיעוּ ${f} שְׁעָרִים וְסָפְגוּ ${a}. מָה הֶפְרֵשׁ הַשְּׁעָרִים שֶׁלָּהֶם?`, correctAnswer: String(f - a), distractors: [String(f + a), ...d(r, f - a)].filter((v) => v !== String(f - a)).slice(0, 3), tier: "medium" }; }
      case 1: { const avg = int(r, 1, 6), m = int(r, 3, 12);
        return { prompt: `📈\n${A} הִבְקִיעוּ ${avg * m} שְׁעָרִים בְּ־${m} מִשְׂחָקִים. כַּמָּה שְׁעָרִים בִּמְמֻצָּע לְמִשְׂחָק?`, correctAnswer: String(avg), distractors: d(r, avg, { min: 0 }), tier: "hard" }; }
      case 2: { const p = pick(r, [25, 30, 40, 50, 60, 80]), n = int(r, 12, 250);
        return { prompt: `🎟️\nכַּרְטִיס לַמִּשְׂחָק עוֹלֶה ${p} ₪. כַּמָּה כֶּסֶף שִׁלְּמוּ ${n} אוֹהֲדִים?`, correctAnswer: `${p * n} ₪`, distractors: numericDistractors(r, p * n, { step: p, fmt: (v) => `${v} ₪` }), tier: "hard" }; }
      default: { const cap = pick(r, [5000, 8000, 12000, 20000, 30000]), sold = int(r, 1000, cap - 500);
        return { prompt: `🏟️\nבָּאִצְטַדְיוֹן יֵשׁ ${cap} מְקוֹמוֹת וְנִמְכְּרוּ ${sold} כַּרְטִיסִים. כַּמָּה מְקוֹמוֹת נִשְׁאֲרוּ פְּנוּיִים?`, correctAnswer: String(cap - sold), distractors: d(r, cap - sold, { step: 10 }), tier: "hard" }; }
    }
  },
  5(r) {
    const [A] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const tot = pick(r, [10, 20, 25, 50]), on = int(r, 1, tot - 1); const pct = on * 100 / tot;
        if (!Number.isInteger(pct)) return null;
        return { prompt: `🎯\n${A} בָּעֲטוּ ${tot} בְּעִיטוֹת, וְ־${on} מֵהֶן הָלְכוּ לַמִּסְגֶּרֶת. כַּמָּה אֲחוּזִים זֶה?`, correctAnswer: `${pct}%`, distractors: pctDistractors(r, pct, tot === 10 ? 10 : 5), tier: "hard" }; }
      case 1: { const m = pick(r, [2, 4, 6, 8]), total = int(r, 1, 20) * 2 + 1; if (total % m === 0) return null; const avg = total / m;
        if (!Number.isInteger(avg * 2)) return null;
        return { prompt: `📈\n${A} הִבְקִיעוּ ${total} שְׁעָרִים בְּ־${m} מִשְׂחָקִים. מָה הַמְּמֻצָּע לְמִשְׂחָק?`, correctAnswer: String(avg), distractors: numericDistractors(r, avg, { step: 0.5 }).map(String), tier: "hard" }; }
      case 2: { const target = int(r, 40, 90), cur = int(r, 10, target - 3);
        return { prompt: `🏆\n${prefixed("לְ", A)} יֵשׁ ${cur} נְקֻדּוֹת. כְּדֵי לִזְכּוֹת בָּאַלִּיפוּת צָרִיךְ ${target}. כַּמָּה נְקֻדּוֹת חֲסֵרוֹת לָהֶם?`, correctAnswer: String(target - cur), distractors: d(r, target - cur), tier: "medium" }; }
      default: { const games = pick(r, [26, 30, 32, 34, 36, 38]), played = int(r, 3, games - 3);
        return { prompt: `📅\nבָּעוֹנָה ${games} מִשְׂחָקִים, וְ${A} שִׂחֲקוּ כְּבָר ${played}. כַּמָּה מִשְׂחָקִים נִשְׁאֲרוּ לָהֶם?`, correctAnswer: String(games - played), distractors: d(r, games - played), tier: "medium" }; }
    }
  },
  6(r) {
    const [A, B] = two(r);
    switch (int(r, 0, 3)) {
      case 0: { const games = pick(r, [10, 20, 25, 40, 50]), wins = int(r, 1, games - 1); const pct = wins * 100 / games;
        if (!Number.isInteger(pct)) return null;
        return { prompt: `📊\n${A} שִׂחֲקוּ ${games} מִשְׂחָקִים וְנִצְּחוּ בְּ־${wins}. בְּאֵיזֶה אָחוּז מֵהַמִּשְׂחָקִים הֵם נִצְּחוּ?`, correctAnswer: `${pct}%`, distractors: pctDistractors(r, pct, 5), tier: "hard" }; }
      case 1: { const k = int(r, 2, 9), a = int(r, 1, 5), b = int(r, 1, 5); if (a === b) return null;
        const gcd = (x, y) => (y ? gcd(y, x % y) : x); const gg = gcd(a, b); if (gg !== 1) return null;
        return { prompt: `⚖️\n${A} הִבְקִיעוּ ${a * k} שְׁעָרִים וְ${B} הִבְקִיעוּ ${b * k}. מָה הַיַּחַס בֵּינֵיהֶם בְּצוּרָה מְצֻמְצֶמֶת?`, correctAnswer: `${a} : ${b}`, distractors: [`${b} : ${a}`, `${a * k} : ${b * k}`, `${a + 1} : ${b}`].filter((x) => x !== `${a} : ${b}`), tier: "hard" }; }
      case 2: { const lead = int(r, 50, 80), cur = int(r, 30, lead - 4); const need = Math.ceil((lead - cur + 1) / 3);
        return { prompt: `🏆\nלַמּוֹבִילָה יֵשׁ ${lead} נְקֻדּוֹת ${and(prefixed("לְ", A))} יֵשׁ ${cur}. כַּמָּה נִצְחוֹנוֹת לְפָחוֹת (3 נְקֻדּוֹת כָּל אֶחָד) הֵם צְרִיכִים כְּדֵי לַעֲקֹף אוֹתָהּ?`, correctAnswer: String(need), distractors: d(r, need, { min: 1 }), tier: "hard" }; }
      default: { const base = int(r, 2, 40) * 1000, pct = pick(r, [10, 20, 25, 50]); const next = base * (100 + pct) / 100;
        return { prompt: `📈\nבַּמִּשְׂחָק הַקּוֹדֵם הָיוּ ${base} אוֹהֲדִים, וְהַפַּעַם הַמִּסְפָּר עָלָה בְּ־${pct}%. כַּמָּה אוֹהֲדִים הָיוּ הַפַּעַם?`, correctAnswer: String(next), distractors: d(r, next, { step: Math.max(100, base * 0.05) }), tier: "hard" }; }
    }
  },
  // ——— ז׳: הֶפְרֵשׁ שְׁלִילִי, מְמֻצָּעִים, טַבְלַת נְקֻדּוֹת, אֲחוּזֵי תְּפוּסָה ———
  7(r) {
    const [A, B] = two(r);
    // A signed answer and its three sign-slip neighbours, all isolated.
    const signedSet = (ans, extra) => { const out = []; for (const v of [-ans, ...extra, ans + 1, ans - 1, ans + 2]) { const sv = signed(v); if (v !== ans && !out.includes(sv) && out.length < 3) out.push(sv); } return out; };
    switch (int(r, 0, 5)) {
      case 0: { const scored = int(r, 20, 45), conceded = scored + int(r, 1, 15);
        return { prompt: `📊\n${A} הִבְקִיעוּ הָעוֹנָה ${scored} שְׁעָרִים וְסָפְגוּ ${conceded}. מָה הֶפְרֵשׁ הַשְּׁעָרִים שֶׁלָּהֶם?`,
          correctAnswer: signed(scored - conceded), distractors: signedSet(scored - conceded, [scored + conceded]), tier: "medium" }; }
      case 1: { const games = pick(r, [4, 6, 8, 10]), half = int(r, 1, 7), total = games * half / 2;
        if (!Number.isInteger(total) || half % 2 === 0) return null;
        const avg = (half / 2).toFixed(1);
        return { prompt: `⚽\n${A} הִבְקִיעוּ ${total} שְׁעָרִים בְּ־${games} מִשְׂחָקִים. מָה מְמֻצַּע הַשְּׁעָרִים לְמִשְׂחָק?`,
          correctAnswer: avg, distractors: [String(Math.floor(half / 2)), String(Math.ceil(half / 2)), (half / 2 + 0.5).toFixed(1), String(games * 2)].filter((x, i, a) => x !== avg && a.indexOf(x) === i).slice(0, 3), tier: "medium" }; }
      case 2: { const w = int(r, 5, 20), dr = int(r, 1, 10), l = int(r, 1, 10), pts = 3 * w + dr;
        return { prompt: `🏆\n${A}: ${w} נִצְחוֹנוֹת, ${dr} תֵּיקוֹ וְ־${l} הֶפְסֵדִים. נִצָּחוֹן = 3 נְקֻדּוֹת, תֵּיקוֹ = נְקֻדָּה אַחַת. כַּמָּה נְקֻדּוֹת יֵשׁ לָהֶם?`,
          correctAnswer: String(pts), distractors: d(r, pts, { min: 1, mistakes: [w + dr + l, 3 * w, 3 * w + dr - l] }), tier: "medium" }; }
      case 3: { const pts = int(r, 30, 70), w = int(r, 5, Math.floor(pts / 3)), dr = pts - 3 * w;
        if (dr < 0 || dr > 15) return null;
        return { prompt: `🏆\n${prefixed("לְ", A)} יֵשׁ ${pts} נְקֻדּוֹת וְ־${w} נִצְחוֹנוֹת. בְּכַמָּה מִשְׂחָקִים הֵם סִיְּמוּ בְּתֵיקוֹ? (נִצָּחוֹן = 3 נְקֻדּוֹת, תֵּיקוֹ = נְקֻדָּה אַחַת)`,
          correctAnswer: String(dr), distractors: d(r, dr, { min: 0, mistakes: [pts - w, Math.round(pts / 3)] }), tier: "hard" }; }
      case 4: { const cap = pick(r, [8000, 12000, 20000, 30000, 40000]), pct = pick(r, [40, 55, 60, 75, 80, 85, 90]), fans = cap * pct / 100;
        return { prompt: `🏟️\nבָּאִצְטַדְיוֹן יֵשׁ ${cap.toLocaleString("en-US")} מְקוֹמוֹת, וְהִגִּיעוּ ${fans.toLocaleString("en-US")} אוֹהֲדִים. אֵיזֶה אָחוּז מֵהַמְּקוֹמוֹת מָלֵא?`,
          correctAnswer: `${pct}%`, distractors: pctDistractors(r, pct, 5), tier: "medium" }; }
      default: { const minutes = int(r, 3, 9) * 90, goals = minutes / 90 * pick(r, [1, 2, 3]) / pick(r, [1, 2]);
        if (!Number.isInteger(goals) || goals < 2) return null;
        const per = minutes / goals;
        if (!Number.isInteger(per)) return null;
        return { prompt: `⏱️\nחָלוּץ שִׂחֵק ${minutes} דַּקּוֹת וְהִבְקִיעַ ${goals} שְׁעָרִים. כָּל כַּמָּה דַּקּוֹת, בִּמְמֻצָּע, הוּא הִבְקִיעַ?`,
          correctAnswer: String(per), distractors: d(r, per, { min: 1, step: 5, mistakes: [goals * 90 / minutes === Math.round(goals * 90 / minutes) ? goals * 90 / minutes : per + 10, minutes - goals] }), tier: "hard" }; }
    }
  },
  // ——— ח׳: הִסְתַּבְּרוּת, מְהִירוּת, שֶׁטַח מִגְרָשׁ, מִשְׁוָאָה, מְמֻצָּע נִדְרָשׁ ———
  8(r) {
    const [A] = two(r);
    switch (int(r, 0, 4)) {
      case 0: { const shots = pick(r, [8, 10, 12, 15, 16, 20, 24, 25, 30]), made = int(r, 1, shots - 1);
        const ans = frac(made, shots), opts = [frac(shots - made, shots), frac(made, shots - made), frac(made + 1, shots + 1), frac(1, shots), frac(made, shots + made)];
        const distractors = [...new Set(opts)].filter((x) => x !== ans).slice(0, 3);
        return { prompt: `🥅\nשׁוֹעֵר עָצַר ${made} מִתּוֹךְ ${shots} פֶּנְדֶּלִים. לְפִי זֶה, מָה הַסִּכּוּי שֶׁהוּא יַעֲצֹר אֶת הַפֶּנְדֵּל הַבָּא?`,
          correctAnswer: ans, distractors, tier: "hard" }; }
      case 1: { const km = int(r, 3, 12) * 3, speed = km / 1.5;
        return { prompt: `🏃\nשַׂחְקָן רָץ ${km} קִילוֹמֶטְרִים בְּמִשְׂחָק שֶׁל 90 דַּקּוֹת. מָה הַמְּהִירוּת הַמְּמֻצַּעַת שֶׁלּוֹ בְּקָמָ"שׁ?`,
          correctAnswer: String(speed), distractors: d(r, speed, { min: 1, mistakes: [km / 90 === Math.round(km / 90) ? km / 90 : speed + 3, km, Math.round(km * 90 / 60 / 1)] }), tier: "hard" }; }
      case 2: { const len = int(r, 100, 110), wid = int(r, 64, 75), area = len * wid;
        return { prompt: `📐\nמִגְרָשׁ כַּדּוּרֶגֶל בְּאֹרֶךְ ${len} מֶטֶר וּבְרֹחַב ${wid} מֶטֶר. מָה הַשֶּׁטַח שֶׁלּוֹ בְּמֶטְרִים רְבוּעִים?`,
          correctAnswer: area.toLocaleString("en-US"), distractors: [2 * (len + wid), area + len, area - wid, len * (wid + 1)].map((x) => x.toLocaleString("en-US")).filter((x, i, a) => x !== area.toLocaleString("en-US") && a.indexOf(x) === i).slice(0, 3), tier: "hard" }; }
      case 3: { const fixed = int(r, 2, 20) * 1000, price = pick(r, [40, 50, 60, 80, 100]), tickets = int(r, 5, 40) * 100, revenue = fixed + price * tickets;
        return { prompt: `🎟️\nהַכְנָסַת הַמִּשְׂחָק הָיְתָה ${revenue.toLocaleString("en-US")} ₪: ${fixed.toLocaleString("en-US")} ₪ מִפִּרְסוֹמוֹת, וְהַשְּׁאָר מִכַּרְטִיסִים שֶׁל ${price} ₪ כָּל אֶחָד. כַּמָּה כַּרְטִיסִים נִמְכְּרוּ?`,
          correctAnswer: tickets.toLocaleString("en-US"), distractors: [Math.round(revenue / price), tickets + 100, tickets - 100, Math.round(fixed / price)].filter((x) => x > 0).map((x) => x.toLocaleString("en-US")).filter((x, i, a) => x !== tickets.toLocaleString("en-US") && a.indexOf(x) === i).slice(0, 3), tier: "hard" }; }
      default: { const n = int(r, 3, 7), target = int(r, 2, 4), sofar = n * target - int(r, 1, 4);
        const need = (n + 1) * target - sofar;
        if (need < 1 || need > 10) return null;
        return { prompt: `⚽\n${A} הִבְקִיעוּ ${sofar} שְׁעָרִים בְּ־${n} מִשְׂחָקִים. כַּמָּה שְׁעָרִים הֵם צְרִיכִים בַּמִּשְׂחָק הַבָּא כְּדֵי שֶׁהַמְּמֻצָּע יִהְיֶה ${target} שְׁעָרִים לְמִשְׂחָק?`,
          correctAnswer: String(need), distractors: d(r, need, { min: 0, mistakes: [target, n * target - sofar] }), tier: "hard" }; }
    }
  },
};

module.exports = { topic: "soccer", byGrade };
