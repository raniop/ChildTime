// Remove every introductory offer (the 7-day free trial) from the Tofy+
// subscriptions in App Store Connect. The gift model replaces the trial —
// with both, a family would get 21 free days (see docs go-to-market review).
// Run:  node tools/asc-trial-off.js
const fs = require("fs"), path = require("path"), os = require("os");
const jwt = require(path.join(__dirname, "..", "functions", "node_modules", "jsonwebtoken"));
const KEY = path.join(os.homedir(), ".appstoreconnect/private_keys/AuthKey_2N6QHTA4QJ.p8");
const tok = () => jwt.sign({ iss: "69a6de6e-f3cf-47e3-e053-5b8c7c11a4d1", aud: "appstoreconnect-v1", exp: Math.floor(Date.now() / 1000) + 900 },
  fs.readFileSync(KEY), { algorithm: "ES256", keyid: "2N6QHTA4QJ" });
async function api(method, u) {
  const r = await fetch("https://api.appstoreconnect.apple.com" + u, { method, headers: { Authorization: "Bearer " + tok() } });
  if (r.status === 204) return { ok: true };
  const j = await r.json().catch(() => ({}));
  if (!r.ok) return { error: (j.errors || [{}])[0] };
  return j;
}
(async () => {
  const groups = await api("GET", "/v1/apps/6773805449/subscriptionGroups");
  if (groups.error) { console.log("groups:", JSON.stringify(groups.error)); return; }
  for (const g of groups.data || []) {
    const subs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptions`);
    for (const s of subs.data || []) {
      // One offer record per TERRITORY (175 of them) — page until none remain.
      let deleted = 0, failed = 0, round = 0;
      while (round++ < 40) {
        const io = await api("GET", `/v1/subscriptions/${s.id}/introductoryOffers?limit=200`);
        if (io.error) { console.log(s.attributes.productId, "list error:", io.error.detail); break; }
        const offers = io.data || [];
        if (round === 1) console.log(s.attributes.productId, "→ intro offers:", offers.length, offers[0] ? `(${offers[0].attributes.offerMode} ${offers[0].attributes.duration}×${offers[0].attributes.numberOfPeriods})` : "");
        if (!offers.length) break;
        for (const o of offers) {
          const d = await api("DELETE", `/v1/subscriptionIntroductoryOffers/${o.id}`);
          if (d.ok) deleted += 1; else { failed += 1; console.log("   delete failed", o.id, JSON.stringify(d.error)); }
        }
        if (failed) break;
      }
      const after = await api("GET", `/v1/subscriptions/${s.id}/introductoryOffers?limit=200`);
      console.log(`   deleted ${deleted}, remaining: ${(after.data || []).length}`);
    }
  }
})();
