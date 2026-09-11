// 🧩 לוגיקה לכיתות ז׳–ח׳ — sequences, calendars, clocks and counting.
//
// Everything is computed, so the answer is right by construction. Sequences sit
// on their own line inside an isolate: "−3, 1, 5, ?" must not reorder in a
// right-to-left question.
"use strict";
const { int, pick, numericDistractors, ltr, signed, prefixed, KIDS, g } = require("./core");

const d = (r, ans, o = {}) => numericDistractors(r, ans, { min: -999, fmt: (v) => signed(v), ...o });
const seq = (terms) => ltr(`${terms.map((t) => (t < 0 ? `−${-t}` : `${t}`)).join(", ")}, ?`);
const NEXT = "מָה הַמִּסְפָּר הַבָּא בַּסִּדְרָה?";
const DAYS = ["יוֹם רִאשׁוֹן", "יוֹם שֵׁנִי", "יוֹם שְׁלִישִׁי", "יוֹם רְבִיעִי", "יוֹם חֲמִישִׁי", "יוֹם שִׁשִּׁי", "שַׁבָּת"];
const fact = (n) => (n <= 1 ? 1 : n * fact(n - 1));
const isPrime = (n) => { if (n < 2) return false; for (let i = 2; i * i <= n; i++) if (n % i === 0) return false; return true; };

function calendar(r, lo, hi) {
  const today = int(r, 0, 6), n = int(r, lo, hi), ans = (today + n) % 7;
  // Off-by-one days are the mistake worth testing.
  const opts = [...new Set([(ans + 1) % 7, (ans + 6) % 7, (ans + 2) % 7, today])].filter((x) => x !== ans).slice(0, 3);
  const todayName = DAYS[today] === "שַׁבָּת" ? "שַׁבָּת" : DAYS[today];
  return { prompt: `📅\nהַיּוֹם ${todayName}. אֵיזֶה יוֹם יִהְיֶה בְּעוֹד ${n} יָמִים?`, correctAnswer: DAYS[ans], distractors: opts.map((x) => DAYS[x]), tier: n > 60 ? "hard" : "medium" };
}

const byGrade = {
  7(r) {
    switch (int(r, 0, 7)) {
      case 0: { const a = int(r, -20, 30), step = int(r, 2, 12) * (r() < 0.4 ? -1 : 1), t = [0, 1, 2, 3].map((i) => a + i * step), ans = a + 4 * step;
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { step: 1, mistakes: [ans + step, a + 3 * step - step, -ans] }), tier: step < 0 ? "medium" : "easy" }; }
      case 1: { const ratio = pick(r, [2, 3]), a = int(r, 1, ratio === 2 ? 12 : 5), t = [0, 1, 2, 3].map((i) => a * ratio ** i), ans = a * ratio ** 4;
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { min: 1, step: a, mistakes: [t[3] + (t[3] - t[2]), t[3] * (ratio + 1), t[3] + ratio] }), tier: "medium" }; }
      case 2: { const n = int(r, 1, 8), cubes = r() < 0.3, p = cubes ? 3 : 2, t = [0, 1, 2, 3].map((i) => (n + i) ** p), ans = (n + 4) ** p;
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { min: 1, mistakes: [t[3] + (t[3] - t[2]), (n + 4) * p, ans + 1] }), tier: "hard" }; }
      case 3: { const a = int(r, 1, 20), s0 = int(r, 1, 3), t = [a]; for (let i = 0; i < 3; i++) t.push(t[i] + s0 + i); const ans = t[3] + s0 + 3;
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { min: 1, mistakes: [t[3] + s0 + 2, t[3] + s0 + 4, t[3] + (t[3] - t[2])] }), tier: "medium" }; }
      case 4: { // two operations taking turns: +add, ×2, +add → the next step is ×2
        const add = int(r, 1, 5), a = int(r, 1, 6), t = [a];
        for (let i = 0; i < 3; i++) t.push(i % 2 === 0 ? t[i] + add : t[i] * 2);   // t[1]=+add, t[2]=×2, t[3]=+add
        const ans = t[3] * 2;                                                      // so the next step is ×2
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { min: 1, mistakes: [t[3] + add, t[3] + (t[3] - t[2]), ans + add] }), tier: "hard" }; }
      case 5: return calendar(r, 8, 45);
      case 6: { const n = int(r, 4, 9), ans = n * (n - 1) / 2;
        return { prompt: `🤝\nבַּמְּסִבָּה ${n} חֲבֵרִים, וְכָל אֶחָד לוֹחֵץ יָד לְכָל אֶחָד מֵהָאֲחֵרִים פַּעַם אַחַת. כַּמָּה לְחִיצוֹת יָד יִהְיוּ?`, correctAnswer: String(ans), distractors: numericDistractors(r, ans, { min: 1, mistakes: [n * (n - 1), n * n, n - 1] }), tier: "hard" }; }
      default: { const k = pick(r, KIDS), shirts = int(r, 2, 7), pants = int(r, 2, 5);
        return { prompt: `👕\n${prefixed("לְ", k.n)} יֵשׁ ${shirts} חֻלְצוֹת וְ־${pants} מִכְנָסַיִם. כַּמָּה צֵרוּפִים שׁוֹנִים שֶׁל חֻלְצָה וּמִכְנָסַיִם ${g(k, "הוּא יָכוֹל", "הִיא יְכוֹלָה")} לִלְבֹּשׁ?`,
          correctAnswer: String(shirts * pants), distractors: numericDistractors(r, shirts * pants, { min: 1, mistakes: [shirts + pants, shirts * pants + pants, shirts * pants - 1] }), tier: "medium" }; }
    }
  },
  8(r) {
    switch (int(r, 0, 7)) {
      case 0: { const a = int(r, 1, 6), b = int(r, a, 9), t = [a, b]; for (let i = 0; i < 3; i++) t.push(t[i] + t[i + 1]); const ans = t[3] + t[4];
        return { prompt: `🧩\n${NEXT}\n${seq(t)}`, correctAnswer: signed(ans), distractors: d(r, ans, { min: 1, mistakes: [t[4] + (t[4] - t[3]), t[4] * 2, t[4] + t[2]] }), tier: "hard" }; }
      case 1: { let p = int(r, 11, 80); while (!isPrime(p)) p++; const t = [p]; while (t.length < 4) { let q = t[t.length - 1] + 1; while (!isPrime(q)) q++; t.push(q); }
        let ans = t[3] + 1; while (!isPrime(ans)) ans++;
        // Wrong options: the odd numbers around it that are not prime.
        const wrong = []; for (let v = t[3] + 1; wrong.length < 3 && v < ans + 20; v++) if (v !== ans && v % 2 === 1 && !isPrime(v)) wrong.push(String(v));
        if (wrong.length < 3) return null;
        return { prompt: `🔢\nבַּסִּדְרָה מִסְפָּרִים רִאשׁוֹנִיִּים עוֹקְבִים. ${NEXT}\n${seq(t)}`, correctAnswer: String(ans), distractors: wrong, tier: "hard" }; }
      case 2: { const n = int(r, 3, 6), what = pick(r, [["סְפָרִים שׁוֹנִים עַל מַדָּף", "📚"], ["יְלָדִים בְּשׁוּרָה", "🧍"], ["מְכוֹנִיּוֹת בְּחַנְיָה שֶׁל " + n + " מְקוֹמוֹת", "🚗"]]);
        const ans = fact(n);
        return { prompt: `${what[1]}\nבְּכַמָּה דְּרָכִים שׁוֹנוֹת אֶפְשָׁר לְסַדֵּר ${n} ${what[0]}?`, correctAnswer: String(ans), distractors: numericDistractors(r, ans, { min: 1, mistakes: [n * n, n * (n - 1), fact(n - 1), 2 * n] }), tier: "hard" }; }
      case 3: { const teams = int(r, 4, 16), twice = r() < 0.5, ans = teams * (teams - 1) / (twice ? 1 : 2);
        return { prompt: `🏆\nבַּלִּיגָה ${teams} קְבוּצוֹת, וְכָל קְבוּצָה מְשַׂחֶקֶת נֶגֶד כָּל קְבוּצָה אַחֶרֶת ${twice ? "פַּעֲמַיִם (בַּבַּיִת וּבַחוּץ)" : "פַּעַם אַחַת"}. כַּמָּה מִשְׂחָקִים יֵשׁ בָּעוֹנָה?`,
          correctAnswer: String(ans), distractors: numericDistractors(r, ans, { min: 1, mistakes: [twice ? ans / 2 : ans * 2, teams * teams, teams * (teams - 1) + (twice ? teams : 0)] }), tier: "hard" }; }
      case 4: { const a = int(r, -10, 15), step = int(r, 2, 9) * (r() < 0.3 ? -1 : 1), n = pick(r, [10, 15, 20, 25, 50, 100]), t = [0, 1, 2, 3].map((i) => a + i * step), ans = a + (n - 1) * step;
        return { prompt: `🧩\nמָה הָאֵיבָר הַ־${n} בַּסִּדְרָה?\n${ltr(`${t.map((v) => (v < 0 ? `−${-v}` : v)).join(", ")}, …`)}`, correctAnswer: signed(ans), distractors: d(r, ans, { step: Math.abs(step), mistakes: [a + n * step, n * step, a + (n - 2) * step] }), tier: "hard" }; }
      case 5: { const [k, m, per] = pick(r, [[3, 2, 1], [4, 3, 2], [5, 3, 1], [4, 2, 0.5], [5, 4, 3], [6, 4, 1.5]]), x = int(r, 2, 16), son = x * per;
        if (!Number.isInteger(son) || son < 4 || son > 20) return null;
        return { prompt: `👨‍👦\nאַבָּא גָּדוֹל פִּי ${k} מִבְּנוֹ. בְּעוֹד ${x} שָׁנִים הוּא יִהְיֶה גָּדוֹל מִמֶּנּוּ פִּי ${m}. בֶּן כַּמָּה הַבֵּן הַיּוֹם?`, correctAnswer: String(son), distractors: numericDistractors(r, son, { min: 1, mistakes: [son * k, x, son + x] }), tier: "hard" }; }
      case 6: return calendar(r, 50, 400);
      default: { const h = int(r, 0, 23), add = int(r, 25, 200), ans = (h + add) % 24, fmt = (x) => ltr(`${String(x).padStart(2, "0")}:00`);
        const wrong = [...new Set([(ans + 1) % 24, (ans + 23) % 24, (h + add % 12) % 24, (ans + 12) % 24])].filter((x) => x !== ans).slice(0, 3);
        return { prompt: `🕘\nהַשָּׁעָה עַכְשָׁיו ${fmt(h)}. מָה תִּהְיֶה הַשָּׁעָה בְּעוֹד ${add} שָׁעוֹת?`, correctAnswer: fmt(ans), distractors: wrong.map(fmt), tier: "hard" }; }
    }
  },
};

module.exports = { topic: "logic", byGrade };
