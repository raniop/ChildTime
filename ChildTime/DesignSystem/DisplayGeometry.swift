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
    /// Where content has to split in two (the fold), in full-screen coordinates.
    @Published private(set) var divisions: [CGRect] = []
    /// What the system covers (the camera), in full-screen coordinates.
    @Published private(set) var occlusions: [CGRect] = []

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

    // MARK: 🎯 Centering on the PHYSICAL screen

    /// How much of the vertical bar's inset to mirror on the opposite side, by
    /// screen. The bar sits on one side only, so content centered in the safe
    /// area sits off the middle of the glass (Rani: "כל מסך אצלנו נראה כאילו
    /// הוא לא ממורכז").
    ///   • Wide (the open foldable, 867pt): the full mirror — dead centre, and
    ///     84pt off a screen that wide costs nothing.
    ///   • Narrow (its outer screen, 382pt): none. Rani compared none / half /
    ///     full on screenshots and kept the width: "אי אפשר להקטין במצב סגור".
    static let balanceWide: CGFloat = 1.0
    static let balanceNarrow: CGFloat = 0
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
                            divisions: [CGRect]? = nil, occlusions: [CGRect]? = nil) {
        var changed = false
        func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<DisplayGeometry, T>, _ v: T?) {
            guard let v, self[keyPath: kp] != v else { return }
            self[keyPath: kp] = v; changed = true
        }
        set(\.hinge, hinge)
        if let angle { set(\.hingeAngle, angle) }
        set(\.verticalBarEdge, bar)
        set(\.divisions, divisions)
        set(\.occlusions, occlusions)
        #if DEBUG
        if changed { print(debugLine) }
        #endif
    }

    /// One line with everything — `DEMO_SCREEN` runs read it from the console.
    var debugLine: String {
        func r(_ c: CGRect) -> String { "(\(Int(c.minX)),\(Int(c.minY)) \(Int(c.width))×\(Int(c.height)))" }
        return "📐 DISPLAY safe=\(Int(safeSize.width))×\(Int(safeSize.height)) "
            + "insets=t\(Int(safeInsets.top)) l\(Int(safeInsets.leading)) b\(Int(safeInsets.bottom)) t\(Int(safeInsets.trailing)) "
            + "short=\(isShort) bar=\(verticalBarEdge.rawValue) hinge=\(hinge.rawValue) "
            + "angle=\(hingeAngle.map { String(format: "%.2f", $0) } ?? "-") "
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
    private var hinge: DisplayGeometry.Hinge = .none
    private var angle: Double?
    /// While a one-sided bar is showing: re-checks the presented screens, which
    /// live outside this view's hierarchy and would otherwise never be told.
    private var balanceTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        installFoldableObservers()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() { super.layoutSubviews(); refresh(); balance() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh(); balance() }

    // MARK: 🎯 Centered on the glass

    /// The foldable's vertical bar is on ONE side, so content centered in the
    /// safe area sits off the middle of the screen (Rani: "כל מסך אצלנו נראה
    /// כאילו הוא לא ממורכז"). The same inset is mirrored on the other side as
    /// `additionalSafeAreaInsets` on every view controller in the window — the
    /// root and each sheet/cover above it (86 presentations; a SwiftUI modifier
    /// at the root reaches none of them). Content moves in, backdrops that
    /// ignore the safe area still run edge to edge.
    ///
    /// Measured from the WINDOW's insets (physical left/right, never including
    /// what is added here — so it can't feed back on itself). Nothing happens on
    /// any device without a one-sided bar.
    private func balance() {
        guard let window else { return }
        let l = window.safeAreaInsets.left, r = window.safeAreaInsets.right
        let gap = abs(l - r)
        var add = UIEdgeInsets.zero
        if gap >= 40 {
            let safeWidth = window.bounds.width - l - r
            let factor = safeWidth >= DisplayGeometry.wideWidth ? DisplayGeometry.balanceWide : DisplayGeometry.balanceNarrow
            let amount = (gap * factor).rounded()
            if l > r { add.right = amount } else { add.left = amount }
        }
        var vc = window.rootViewController
        while let c = vc {
            if c.additionalSafeAreaInsets != add { c.additionalSafeAreaInsets = add }
            vc = c.presentedViewController
        }
        if add == .zero {
            balanceTimer?.invalidate(); balanceTimer = nil
        } else if balanceTimer == nil {
            balanceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.balance() }
            }
        }
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
            divisions = reservedRegions(kind: .division).filter(\.isActive).map(\.frame)
            occlusions = reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
        }
        #endif
        let (h, a) = (hinge, angle)
        Task { @MainActor in
            DisplayGeometry.shared.update(hinge: h, angle: .some(a), bar: bar,
                                          divisions: divisions, occlusions: occlusions)
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
        if #available(iOS 17.0, *), display.isWideShort {
            content.contentMargins(.horizontal,
                                   max(16, (display.safeSize.width - DisplayGeometry.readableWidth) / 2),
                                   for: .scrollContent)
        } else {
            content
        }
    }
}

extension View {
    /// See `ReadableWidthOnWideShort`.
    func readableOnWideShort() -> some View { modifier(ReadableWidthOnWideShort()) }
}
