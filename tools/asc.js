#!/usr/bin/env node
// App Store Connect API helper (JWT from ~/.appstoreconnect/private_keys).
// The .p8 stays on disk; Key ID / Issuer ID are not secrets.
//   node tools/asc.js apps
//   node tools/asc.js iaps
//   node tools/asc.js create-pack <productId> <sibling|full> <name-he> <desc-he> <price ILS> <screenshot.png>
const fs = require("fs"), path = require("path"), os = require("os"), crypto = require("crypto");
const jwt = require(path.join(__dirname, "..", "functions", "node_modules", "jsonwebtoken"));

const KEY_ID = process.env.ASC_KEY_ID || "2N6QHTA4QJ";
const ISSUER = process.env.ASC_ISSUER_ID || "69a6de6e-f3cf-47e3-e053-5b8c7c11a4d1";
const BUNDLE = "com.rani.ChildTime";
const keyPath = path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`);

function token() {
  return jwt.sign({ iss: ISSUER, aud: "appstoreconnect-v1", exp: Math.floor(Date.now() / 1000) + 19 * 60 },
    fs.readFileSync(keyPath), { algorithm: "ES256", keyid: KEY_ID });
}
async function api(method, url, body) {
  const full = url.startsWith("http") ? url : "https://api.appstoreconnect.apple.com" + url;
  const res = await fetch(full, { method, headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  let json = null; try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  if (!res.ok) throw new Error(`${method} ${url} → ${res.status}: ${JSON.stringify(json && json.errors || json).slice(0, 600)}`);
  return json;
}
async function all(url) { let out = [], next = url; while (next) { const j = await api("GET", next); out = out.concat(j.data || []); next = j.links && j.links.next; } return out; }

async function appID() {
  const j = await api("GET", `/v1/apps?filter[bundleId]=${BUNDLE}`);
  if (!j.data.length) throw new Error("app not found");
  return j.data[0].id;
}

async function createPack([productId, kind, nameHe, descHe, priceILS, screenshot]) {
  const app = await appID();
  const existing = await all(`/v1/apps/${app}/inAppPurchasesV2?limit=200`);
  let iap = existing.find((x) => x.attributes.productId === productId);
  if (iap) console.log("exists:", productId, iap.id, iap.attributes.state);
  else {
    iap = (await api("POST", "/v2/inAppPurchases", { data: { type: "inAppPurchases",
      attributes: { name: kind === "sibling" ? `${nameHe} · ילד נוסף` : nameHe, productId, inAppPurchaseType: "CONSUMABLE",
        reviewNote: "Question pack (add-on world) bought by a PARENT for one child, behind the parental gate. Consumable so a family can buy the same pack for a second child at the sibling price. Never shown with a price on a child device." },
      relationships: { app: { data: { type: "apps", id: app } } } } })).data;
    console.log("created:", productId, iap.id);
  }
  // Localizations (he + en-US)
  const locs = await all(`/v2/inAppPurchases/${iap.id}/inAppPurchaseLocalizations`);
  const want = [["he", kind === "sibling" ? `${nameHe} · ילד נוסף` : nameHe, descHe],
                ["en-US", kind === "sibling" ? "Soccer World · another child" : "Soccer World", "Soccer question pack for one child (add-on)."]];
  for (const [locale, name, description] of want) {
    if (locs.find((l) => l.attributes.locale === locale)) { console.log("loc exists", locale); continue; }
    await api("POST", "/v1/inAppPurchaseLocalizations", { data: { type: "inAppPurchaseLocalizations", attributes: { locale, name, description },
      relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap.id } } } } });
    console.log("loc added", locale);
  }
  // Price: find the ISR price point closest to the wanted ILS price
  const points = await all(`/v2/inAppPurchases/${iap.id}/pricePoints?filter[territory]=ISR&limit=8000`);
  const target = Number(priceILS);
  const best = points.map((p) => ({ id: p.id, price: Number(p.attributes.customerPrice) })).sort((a, b) => Math.abs(a.price - target) - Math.abs(b.price - target))[0];
  console.log("price point ISR:", best && best.price, "for", target);
  try {
    await api("POST", "/v1/inAppPurchasePriceSchedules", { data: { type: "inAppPurchasePriceSchedules",
      relationships: { inAppPurchase: { data: { type: "inAppPurchases", id: iap.id } },
        baseTerritory: { data: { type: "territories", id: "ISR" } },
        manualPrices: { data: [{ type: "inAppPurchasePrices", id: "${price1}" }] } } },
      included: [{ type: "inAppPurchasePrices", id: "${price1}", attributes: { startDate: null },
        relationships: { inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: best.id } } } }] });
    console.log("price schedule set");
  } catch (e) { console.log("price schedule:", e.message.slice(0, 200)); }
  // Availability: every territory, and new ones automatically
  try {
    const terr = await all("/v1/territories?limit=200");
    await api("POST", "/v1/inAppPurchaseAvailabilities", { data: { type: "inAppPurchaseAvailabilities", attributes: { availableInNewTerritories: true },
      relationships: { inAppPurchase: { data: { type: "inAppPurchases", id: iap.id } },
        availableTerritories: { data: terr.map((t) => ({ type: "territories", id: t.id })) } } } });
    console.log("availability set:", terr.length, "territories");
  } catch (e) { console.log("availability:", e.message.slice(0, 200)); }
  // Review screenshot
  if (screenshot) {
    try {
      const have = await api("GET", `/v2/inAppPurchases/${iap.id}/appStoreReviewScreenshot`).catch(() => null);
      if (have && have.data) console.log("screenshot exists");
      else {
        const buf = fs.readFileSync(screenshot);
        const r = await api("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", { data: { type: "inAppPurchaseAppStoreReviewScreenshots",
          attributes: { fileName: path.basename(screenshot), fileSize: buf.length },
          relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap.id } } } } });
        for (const op of r.data.attributes.uploadOperations) {
          const h = {}; for (const x of op.requestHeaders) h[x.name] = x.value;
          const up = await fetch(op.url, { method: op.method, headers: h, body: buf.subarray(op.offset, op.offset + op.length) });
          if (!up.ok) throw new Error("upload part failed " + up.status);
        }
        await api("PATCH", `/v1/inAppPurchaseAppStoreReviewScreenshots/${r.data.id}`, { data: { type: "inAppPurchaseAppStoreReviewScreenshots", id: r.data.id,
          attributes: { uploaded: true, sourceFileChecksum: crypto.createHash("md5").update(buf).digest("hex") } } });
        console.log("screenshot uploaded");
      }
    } catch (e) { console.log("screenshot:", e.message.slice(0, 300)); }
  }
  const fresh = await api("GET", `/v2/inAppPurchases/${iap.id}`);
  console.log("state:", fresh.data.attributes.state);
}

(async () => {
  const [cmd, ...args] = process.argv.slice(2);
  if (cmd === "apps") { const j = await api("GET", "/v1/apps?limit=50"); for (const a of j.data) console.log(a.id, a.attributes.bundleId, a.attributes.name); }
  else if (cmd === "iaps") { const app = await appID(); for (const x of await all(`/v1/apps/${app}/inAppPurchasesV2?limit=200`)) console.log(x.id, x.attributes.productId, x.attributes.inAppPurchaseType, x.attributes.state); }
  else if (cmd === "create-pack") await createPack(args);
  else console.log("usage: apps | iaps | create-pack <productId> <full|sibling> <name-he> <desc-he> <priceILS> [screenshot.png]");
})().catch((e) => { console.error("ERROR", e.message); process.exit(1); });
