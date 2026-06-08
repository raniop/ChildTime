//
//  PaywallScreenshotTests.swift
//  ChildTimeUITests
//
//  Captures a clean screenshot of the "טופי+" subscription paywall with the
//  real StoreKit prices loaded — used as App Review proof that the subscription
//  is offered and functional inside the app.
//
//  How it works:
//   • Launches the app in DEMO_SCREEN=paywall mode (renders PaywallView directly,
//     no splash / no system prompts).
//   • The scheme's StoreKit configuration (ChildTime/Tofy.storekit) makes
//     Product.products(for:) return the local monthly/yearly plans, so the UI
//     shows ₪19.90 / ₪149 with the 7-day trial — not the "products unavailable"
//     placeholder.
//   • Waits until a price-bearing element appears, then attaches a full-screen
//     screenshot to the test result (extracted from the .xcresult afterwards).
//
//  Run:
//    xcodebuild test -scheme ChildTime \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//      -only-testing:ChildTimeUITests/PaywallScreenshotTests/testCapturePaywall
//
import XCTest

final class PaywallScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePaywall() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "paywall"
        app.launch()

        // The plan cards only render once StoreKit has returned the products.
        // The yearly plan label ("שנתי") only exists when a real Product loaded,
        // so it's a reliable "prices are showing" signal.
        let yearlyPlan = app.staticTexts["שנתי"]
        let loaded = yearlyPlan.waitForExistence(timeout: 45)

        XCTAssertTrue(
            loaded,
            "Paywall prices never loaded — StoreKit local config likely not applied to the test run."
        )

        // Give the entrance animations (hero scale, confetti burst) a beat to settle.
        Thread.sleep(forTimeInterval: 1.5)

        // 1) Top of the paywall — brand, value props.
        attach(app.screenshot(), name: "Paywall-Top")

        // 2) Scroll down to the purchasable plans + price + CTA — this is the
        //    part App Review needs: the actual subscription offer with prices.
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app.screenshot(), name: "Paywall-Plans")
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let a = XCTAttachment(screenshot: screenshot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
