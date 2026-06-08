# App Review — Subscription proof screenshots

Screenshots of the live "טופי+" subscription paywall, captured on **iPhone 17 Pro Max
(6.9", 1320×2868)** for Apple's App Review (proof that the subscription is offered and
functional inside the app).

| File | Shows |
|------|-------|
| `paywall-top-6.9.png`   | Brand + everything the subscription unlocks (all topics, all worlds, unlimited reward time, all kids, weekly reports, cross-device sync) |
| `paywall-plans-6.9.png` | The purchasable plans — **חודשי** / **שנתי** — with price, duration, the 7-day free trial, the post-trial terms line, "Restore purchase", and Terms / Privacy links |

## Note on currency
Prices render in **USD ($5.99 / $39.99)** because the iOS Simulator's StoreKit local-testing
storefront is locked to the US in headless runs (the `_storefront: ISR` field in
`ChildTime/Tofy.storekit` is ignored by `xcodebuild test`). The real prices are
**₪19.90 / month** and **₪149 / year** as configured in App Store Connect. The screenshots
prove the subscription UI is implemented and reachable — currency is not relevant to that.
To capture in ₪, run from the Xcode GUI with *Debug ▸ StoreKit ▸ Manage Storefront ▸ Israel*.

## How these were generated
1. Scheme `ChildTime` references `ChildTime/Tofy.storekit` via the test plan `ChildTime.xctestplan`
   (so StoreKit returns the local products).
2. `ChildTimeApp` renders the paywall directly when launched with env `DEMO_SCREEN=paywall`.
3. The UI test captures the screens:

```sh
xcodebuild test \
  -project ChildTime.xcodeproj -scheme ChildTime -testPlan ChildTime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ChildTimeUITests/PaywallScreenshotTests/testCapturePaywall \
  -resultBundlePath /tmp/PaywallShot.xcresult CODE_SIGNING_ALLOWED=NO

# then export the attachments:
xcrun xcresulttool export attachments --path /tmp/PaywallShot.xcresult --output-path ./out
```
