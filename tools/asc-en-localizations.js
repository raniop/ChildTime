// Adds the missing en-US App Store Connect localizations from tools/i18n/asc-en-US-draft.json
// (approved by Rani: "תעשה הכל"). Apple refuses these while a version is in review
// (409 UNMODIFIABLE) — rerun after review: node tools/asc-en-localizations.js
// Idempotent: skips any locale that already exists.
const fs = require("fs"), path = require("path"), os = require("os");
const ROOT = "/Users/raniophir/ChildTime";
const jwt = require(path.join(ROOT, "functions", "node_modules", "jsonwebtoken"));
const KEY_ID = "2N6QHTA4QJ", ISSUER = "69a6de6e-f3cf-47e3-e053-5b8c7c11a4d1", BUNDLE = "com.rani.ChildTime";
const key = fs.readFileSync(path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`));
const token = () => jwt.sign({ iss: ISSUER, aud: "appstoreconnect-v1", exp: Math.floor(Date.now() / 1000) + 19 * 60 }, key, { algorithm: "ES256", keyid: KEY_ID });
async function api(method, url, body) {
  const res = await fetch(url.startsWith("http") ? url : "https://api.appstoreconnect.apple.com" + url, { method, headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
  const t = await res.text(); let j = null; try { j = t ? JSON.parse(t) : null; } catch { j = { raw: t }; }
  if (!res.ok) throw new Error(`${method} ${url} → ${res.status}: ${JSON.stringify((j && j.errors) || j).slice(0, 400)}`); return j;
}
async function all(url) { let out = [], next = url; while (next) { const j = await api("GET", next); out = out.concat(j.data || []); next = j.links && j.links.next; } return out; }
const draft = JSON.parse(fs.readFileSync(path.join(ROOT, "tools/i18n/asc-en-US-draft.json"), "utf8"));
async function step(label, fn) { try { console.log("✅", label, await fn()); } catch (e) { console.log("❌", label, e.message); } }
(async () => {
  const app = (await api("GET", `/v1/apps?filter[bundleId]=${BUNDLE}`)).data[0];
  for (const info of await all(`/v1/apps/${app.id}/appInfos`)) {
    await step(`appInfo ${info.attributes.appStoreState || info.attributes.state}`, async () => {
      const locs = await all(`/v1/appInfos/${info.id}/appInfoLocalizations`);
      if (locs.find((l) => l.attributes.locale === "en-US")) return "exists";
      const a = draft.appInfo;
      await api("POST", "/v1/appInfoLocalizations", { data: { type: "appInfoLocalizations", attributes: { locale: "en-US", name: a.name, subtitle: a.subtitle }, relationships: { appInfo: { data: { type: "appInfos", id: info.id } } } } });
      return "added";
    });
  }
  for (const g of await all(`/v1/apps/${app.id}/subscriptionGroups`)) {
    await step(`subscription group ${g.attributes.referenceName}`, async () => {
      const locs = await all(`/v1/subscriptionGroups/${g.id}/subscriptionGroupLocalizations`);
      if (locs.find((l) => l.attributes.locale === "en-US")) return "exists";
      await api("POST", "/v1/subscriptionGroupLocalizations", { data: { type: "subscriptionGroupLocalizations", attributes: { locale: "en-US", name: draft.subscriptionGroup.name }, relationships: { subscriptionGroup: { data: { type: "subscriptionGroups", id: g.id } } } } });
      return "added";
    });
    for (const s of await all(`/v1/subscriptionGroups/${g.id}/subscriptions`)) {
      const want = draft.subscriptions[s.attributes.productId]; if (!want) continue;
      await step(`subscription ${s.attributes.productId}`, async () => {
        const locs = await all(`/v1/subscriptions/${s.id}/subscriptionLocalizations`);
        if (locs.find((l) => l.attributes.locale === "en-US")) return "exists";
        await api("POST", "/v1/subscriptionLocalizations", { data: { type: "subscriptionLocalizations", attributes: { locale: "en-US", name: want.name, description: want.description }, relationships: { subscription: { data: { type: "subscriptions", id: s.id } } } } });
        return "added";
      });
    }
  }
  for (const x of await all(`/v1/apps/${app.id}/inAppPurchasesV2?limit=200`)) {
    const want = draft.inAppPurchases[x.attributes.productId]; if (!want) continue;
    await step(`iap ${x.attributes.productId}`, async () => {
      const locs = await all(`/v2/inAppPurchases/${x.id}/inAppPurchaseLocalizations`);
      if (locs.find((l) => l.attributes.locale === "en-US")) return "exists";
      await api("POST", "/v1/inAppPurchaseLocalizations", { data: { type: "inAppPurchaseLocalizations", attributes: { locale: "en-US", name: want.name, description: want.description }, relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: x.id } } } } });
      return "added";
    });
  }
})().catch((e) => { console.error("ERROR", e.message); process.exit(1); });
