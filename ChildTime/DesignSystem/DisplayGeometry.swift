import SwiftUI
import Combine
import UIKit

/// 📐 What the screen in the child's hands actually looks like.
///
/// Built for the foldable iPhone (iPhone Duo, iOS 27.1), and useful on every
/// other device: a short screen is a short screen, whether it's a Duo held
/// open or an iPhone SE.
///
/// Apple exposes the foldable's geometry only through UIKit, in the iOS 27.1
/// SDK — SwiftUI has no public API for any of it:
///   • `UIHingeInteraction`       closed / partially open / fully open, and the angle
///   • `UITraitCollection.verticalBarEdge`  the side the system moved the status bar to
///   • `UIView.reservedRegions(kind:)`      `.occlusion` (the camera) and `.division` (the fold)
/// So a transparent UIView at the root of the app reads them and publishes
/// plain values here, and SwiftUI screens observe `DisplayGeometry.shared`.
///
/// The 27.1 part is compiled only against an SDK that has it
/// (`canImport(UIKit, _version: 9127.0.85)` — false with Xcode 27.0, true with
/// 27.1), so an upload built with 27.0 still compiles and simply never sees a
/// hinge. At runtime it is also gated on iOS 27.1.
/// The root's size and safe area — outside the @MainActor class so it can be
/// handed to `onGeometryChange`, which needs a Sendable, non-isolated value.
nonisolated struct DisplayLayout: Equatable, Sendable {
    var size: CGSize
    var insets: EdgeInsets
}

@MainActor
final class DisplayGeometry: ObservableObject {
    static let shared = DisplayGeometry()

    enum Hinge: String, Equatable { case none, unknown, closed, partiallyOpen, fullyOpen }
    enum BarEdge: String, Equatable { case none, leading, trailing }

    /// The usable size inside the safe area.
    @Published private(set) var safeSize: CGSize = .zero
    @Published private(set) var safeInsets: EdgeInsets = .init()
    @Published private(set) var hinge: Hinge = .none
    /// Radians. System policy decides how often it updates — prefer `hinge`.
    @Published private(set) var hingeAngle: Double?
    @Published private(set) var verticalBarEdge: BarEdge = .none
    /// UIKit's own horizontal size class — what decides whether SwiftUI's
    /// NavigationSplitView shows two columns or collapses to one.
    @Published private(set) var sizeClass: String = "-"
    /// Where content has to split in two (the fold), in full-screen coordinates.
    @Published private(set) var divisions: [CGRect] = []
    /// What the system covers (the camera, and the vertical bar's own items),
    /// in full-screen coordinates.
    @Published private(set) var occlusions: [CGRect] = []
    /// The whole glass, before ANY safe area — window bounds. The safe size
    /// above is what SwiftUI lays out in; this is what the rail is placed on.
    @Published private(set) var screenSize: CGSize = .zero
    /// The inset the SYSTEM took for the vertical bar, read from the WINDOW —
    /// a navigation controller mirrors it onto the far side as well, and that
    /// mirror must not be mistaken for a second bar.
    @Published private(set) var barInset: CGFloat = 0
    /// Which PHYSICAL side that bar is on. `verticalBarEdge` reports `.trailing`
    /// even in Hebrew, so it cannot answer this — the window's insets can.
    @Published private(set) var barOnLeft: Bool = false

    /// Below this usable height a phone layout stops fitting: the Duo held
    /// open (≈658pt) and the iPhone SE (647pt) are under it, a 13 mini (728)
    /// and every other iPhone are over it.
    static let shortHeight: CGFloat = 700

    /// A short screen — tighten vertical spacing, keep the primary action visible.
    var isShort: Bool { safeSize.height > 0 && safeSize.height < Self.shortHeight }

    /// Wide AND short — the foldable held open (867×635): a landscape canvas
    /// that a phone's single column wastes. Screens there go side by side and
    /// cap their rows at a readable width. No iPad qualifies (the shortest,
    /// an iPad mini in landscape, keeps ~724pt), and no iPhone is this wide.
    var isWideShort: Bool { isShort && safeSize.width >= Self.wideWidth }

    /// A comfortable reading width for rows and single-column content on a
    /// wide screen — label and control within one glance.
    static let readableWidth: CGFloat = 600

    /// Is there a fold the layout must not put anything across?
    var hasFold: Bool { !divisions.isEmpty }

    // MARK: 🎚 The vertical bar's strip — ours below what the system reserved

    /// The foldable moved the status bar to a strip down one side. Only the
    /// TOP of that strip belongs to the system, and it says exactly how much:
    /// a `.occlusion` region over the strip, 170pt closed and 120pt open.
    /// Measured on both Duos: a tap above that line is swallowed, a tap below
    /// it reaches our views — so the rest of the strip is ours to use.
    var hasBarStrip: Bool { barInset >= 40 && screenSize.width > 0 }

    /// The strip in full-screen coordinates (empty when there is no bar).
    var barStrip: CGRect {
        guard hasBarStrip else { return .zero }
        return CGRect(x: barOnLeft ? 0 : screenSize.width - barInset, y: 0,
                      width: barInset, height: screenSize.height)
    }

    /// How far down the strip the system's own items reach. Anything we draw
    /// starts below this — above it the touch never arrives.
    var barStripTop: CGFloat {
        let strip = barStrip
        guard !strip.isEmpty else { return 0 }
        return occlusions.filter { $0.intersects(strip) }.map(\.maxY).max() ?? 0
    }

    // MARK: 🎯 Centering on the PHYSICAL screen — the system's job, not ours

    /// Above this safe width a screen counts as wide.
    static let wideWidth: CGFloat = 600

    /// The size and safe area SwiftUI actually lays the root out in. Taken from
    /// the root's GeometryProxy — the UIView below did NOT reliably receive the
    /// safe area inside SwiftUI (an iPhone 18 Pro read 0 insets and 874pt).
    typealias Layout = DisplayLayout

    func updateLayout(_ layout: Layout) {
        var changed = false
        if safeSize != layout.size { safeSize = layout.size; changed = true }
        if safeInsets != layout.insets { safeInsets = layout.insets; changed = true }
        #if DEBUG
        if changed { print(debugLine) }
        #endif
    }

    fileprivate func update(hinge: Hinge? = nil, angle: Double?? = nil, bar: BarEdge? = nil,
                            sizeClass: String? = nil,
                            divisions: [CGRect]? = nil, occlusions: [CGRect]? = nil,
                            screenSize: CGSize? = nil, barInset: CGFloat? = nil,
                            barOnLeft: Bool? = nil) {
        var changed = false
        func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<DisplayGeometry, T>, _ v: T?) {
            guard let v, self[keyPath: kp] != v else { return }
            self[keyPath: kp] = v; changed = true
        }
        set(\.hinge, hinge)
        if let angle { set(\.hingeAngle, angle) }
        set(\.verticalBarEdge, bar)
        set(\.sizeClass, sizeClass)
        set(\.divisions, divisions)
        set(\.occlusions, occlusions)
        set(\.screenSize, screenSize)
        set(\.barInset, barInset)
        set(\.barOnLeft, barOnLeft)
        #if DEBUG
        if changed { print(debugLine) }
        #endif
    }

    /// One line with everything — `DEMO_SCREEN` runs read it from the console.
    var debugLine: String {
        func r(_ c: CGRect) -> String { "(\(Int(c.minX)),\(Int(c.minY)) \(Int(c.width))×\(Int(c.height)))" }
        return "📐 DISPLAY safe=\(Int(safeSize.width))×\(Int(safeSize.height)) "
            + "insets=t\(Int(safeInsets.top)) l\(Int(safeInsets.leading)) b\(Int(safeInsets.bottom)) t\(Int(safeInsets.trailing)) "
            + "short=\(isShort) wideShort=\(isWideShort) hsc=\(sizeClass) bar=\(verticalBarEdge.rawValue) hinge=\(hinge.rawValue) "
            + "angle=\(hingeAngle.map { String(format: "%.2f", $0) } ?? "-") "
            + "screen=\(Int(screenSize.width))×\(Int(screenSize.height)) strip=\(Int(barInset))@\(barOnLeft ? "L" : "R")+\(Int(barStripTop)) "
            + "divisions=\(divisions.map(r)) occlusions=\(occlusions.map(r))"
    }
}

/// The transparent reader for the UIKit-only facts (hinge, vertical bar,
/// reserved regions). Put it once, full screen, at the root:
/// `DisplayProbe().ignoresSafeArea()` — and feed the root's GeometryProxy to
/// `updateLayout` for the size and safe area.
struct DisplayProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> DisplayProbeView { DisplayProbeView() }
    func updateUIView(_ uiView: DisplayProbeView, context: Context) {}
}

final class DisplayProbeView: UIView {
    /// What a screen gets above its content when the status bar is not there to
    /// provide it. A hair under the 20pt a classic status bar took.
    static let minimumTopMargin: CGFloat = 16

    private var hinge: DisplayGeometry.Hinge = .none
    private var angle: Double?
    /// Keeps the un-mirroring true for screens that appear later — a pushed
    /// page, a sheet, a full-screen cover — which are not in this view's
    /// hierarchy and would otherwise never be visited.
    private var sweepTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        installFoldableObservers()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() { super.layoutSubviews(); refresh(); unmirrorVerticalBar() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh(); unmirrorVerticalBar() }

    // MARK: 📐 Give the page back the width the bar's mirror took

    /// On the foldable a `UINavigationController` adds the vertical bar's inset
    /// to BOTH sides of its content, so the page stays optically centred between
    /// the bar and the far edge. Every pushed page, sheet and cover in the app
    /// inherits that — the parent's home ran 266pt wide inside a 382pt safe area,
    /// with 84pt of dead glass opposite the bar (Rani: "זה ממש ניצול על הפנים
    /// של המסך"). With the app's own rail living in the bar's strip there is
    /// nothing to centre against, so the mirror is cancelled.
    ///
    /// Done once here for the whole window rather than screen by screen: the
    /// mirror is added by UIKit, so it is removed in UIKit. Each controller is
    /// measured, never assumed — `additionalSafeAreaInsets` is set to exactly
    /// minus what the system put on the far side, so a screen that never had a
    /// mirror is left alone and the correction cannot compound.
    private func unmirrorVerticalBar() {
        guard let window else { return }
        let l = window.safeAreaInsets.left, r = window.safeAreaInsets.right
        let bar = max(l, r)
        let active = bar >= 40 && abs(l - r) >= 40
        let barOnLeft = l > r

        var touched = false
        forEachViewController(from: window.rootViewController) { vc in
            guard vc.isViewLoaded else { return }
            var add = vc.additionalSafeAreaInsets
            // What the SYSTEM gives on the side the bar is not on — our own
            // correction is subtracted back out so this reads the same value
            // on every pass instead of chasing itself.
            let insets = vc.view.safeAreaInsets
            let far = barOnLeft ? insets.right - add.right : insets.left - add.left
            let want = active ? -max(0, far) : 0
            let current = barOnLeft ? add.right : add.left

            // ⬆️ With the status bar moved to the side, the TOP safe area is 0
            // and every screen in the app sat flush against the glass (Rani:
            // "הוא קרוב מדי למעלה, זה לא נראה טוב"). Give the top back the
            // margin a status bar used to provide — measured the same way, so
            // a screen that already has a top inset is left alone.
            let systemTop = insets.top - add.top
            let wantTop = active ? max(0, Self.minimumTopMargin - systemTop) : 0

            guard abs(current - want) > 0.5 || abs(add.top - wantTop) > 0.5 else { return }
            if barOnLeft { add.right = want } else { add.left = want }
            add.top = wantTop
            vc.additionalSafeAreaInsets = add
            touched = true
        }
        if touched { window.layoutIfNeeded() }

        if active, sweepTimer == nil {
            sweepTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.unmirrorVerticalBar() }
            }
        } else if !active {
            sweepTimer?.invalidate(); sweepTimer = nil
        }
    }

    /// Every view controller currently in the window: the root, its children,
    /// and whatever each of them has presented.
    private func forEachViewController(from root: UIViewController?, _ body: (UIViewController) -> Void) {
        guard let root else { return }
        body(root)
        for child in root.children { forEachViewController(from: child, body) }
        forEachViewController(from: root.presentedViewController, body)
    }

    private func installFoldableObservers() {
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            addInteraction(UIHingeInteraction { [weak self] _, update in
                guard let self else { return }
                if let h = update.hinge {
                    switch h.status {
                    case .closed:        self.hinge = .closed
                    case .partiallyOpen: self.hinge = .partiallyOpen
                    case .fullyOpen:     self.hinge = .fullyOpen
                    default:             self.hinge = .unknown
                    }
                    self.angle = Double(h.angle)
                } else {
                    // Left a hierarchy that reports a hinge — no hinge here.
                    self.hinge = .none
                    self.angle = nil
                }
                // The fold's reserved region moves with the hinge.
                self.setNeedsLayout()
                self.refresh()
            })
            registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (view: DisplayProbeView, _) in
                view.refresh()
            }
        }
        #endif
    }

    private func refresh() {
        guard window != nil else { return }
        var bar: DisplayGeometry.BarEdge = .none
        var divisions: [CGRect] = []
        var occlusions: [CGRect] = []
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            switch traitCollection.verticalBarEdge {
            case .leading:  bar = .leading
            case .trailing: bar = .trailing
            default:        bar = .none
            }
            // In the WINDOW's coordinates, not this view's: a screen that lays
            // itself out wider than the glass would otherwise shift every rect
            // and the strip would stop matching (measured: a 1165pt-wide root
            // reported the bar's occlusion at x=974 on a 951pt screen).
            divisions = reservedRegions(kind: .division).filter(\.isActive)
                .map { convert($0.frame, to: nil) }
            occlusions = reservedRegions(kind: .occlusion).filter(\.isActive)
                .map { convert($0.frame, to: nil) }
        }
        #endif
        let sc: String
        switch traitCollection.horizontalSizeClass {
        case .compact: sc = "compact"
        case .regular: sc = "regular"
        default:       sc = "-"
        }
        // The WINDOW's insets: a UINavigationController mirrors the bar's inset
        // onto the far side to keep its content optically centred, and reading
        // that back would say "a bar on both sides".
        let screen = window?.bounds.size ?? .zero
        let wl = window?.safeAreaInsets.left ?? 0, wr = window?.safeAreaInsets.right ?? 0
        let inset = max(wl, wr), onLeft = wl > wr
        let (h, a) = (hinge, angle)
        Task { @MainActor in
            DisplayGeometry.shared.update(hinge: h, angle: .some(a), bar: bar, sizeClass: sc,
                                          divisions: divisions, occlusions: occlusions,
                                          screenSize: screen, barInset: inset, barOnLeft: onLeft)
        }
    }
}

/// 📐 Rows at a readable width on a wide, short screen (the open foldable).
/// A Form there ran its rows 780pt across — the label on one side and its
/// switch on the other, too far apart to read as one line. `contentMargins`
/// narrows the rows INSIDE the scroll view, so the backdrop behind still runs
/// edge to edge. Nothing changes anywhere else.
struct ReadableWidthOnWideShort: ViewModifier {
    @ObservedObject private var display = DisplayGeometry.shared

    func body(content: Content) -> some View {
        if display.isWideShort, display.safeSize.width > DisplayGeometry.readableWidth {
            // A capped, centred frame — NOT `contentMargins(for: .scrollContent)`,
            // which measured on the open Duo as doing nothing to a Form: the rows
            // still ran the full 867pt with the label at one edge and its control
            // at the other. This is also what iOS itself does with a Form on a
            // wide screen: one readable column in the middle.
            content
                .frame(maxWidth: DisplayGeometry.readableWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// See `ReadableWidthOnWideShort`.
    func readableOnWideShort() -> some View { modifier(ReadableWidthOnWideShort()) }
}
