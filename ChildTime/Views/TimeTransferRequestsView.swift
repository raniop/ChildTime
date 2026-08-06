import SwiftUI

/// Parent screen listing sibling time-transfer requests: those awaiting approval
/// (with Approve / Reject) on top, and the decided history below. Lives on its own
/// screen so the dashboard stays compact instead of growing an endless list.
struct TimeTransferRequestsView: View {
    @ObservedObject private var transfers = TimeTransferManager.shared
    @Environment(\.dismiss) private var dismiss

    private var pending: [TimeTransfer] { transfers.pendingForParent }
    /// Decided requests only — not the ones still awaiting the parent OR still
    /// waiting for the sibling to agree (those aren't the parent's concern yet).
    private var history: [TimeTransfer] {
        transfers.allTransfers.filter { $0.status != .pendingParent && $0.status != .pendingSeller }
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    if pending.isEmpty && history.isEmpty {
                        emptyState
                    } else {
                        if !pending.isEmpty {
                            sectionHeader("מַמְתִּינוֹת לְאִשּׁוּר")
                            ForEach(pending) { pendingRow($0) }
                        }
                        if !history.isEmpty {
                            sectionHeader("הִיסְטוֹרְיָה")
                            ForEach(history) { historyRow($0) }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top) { topBar }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var topBar: some View {
        ZStack {
            Text("בַּקָּשׁוֹת הַעֲבָרַת זְמַן")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(Circle().fill(.white.opacity(0.2)))
                }
                Spacer()
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.0))
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🛒").font(.system(size: 54))
            Text("אֵין בַּקָּשׁוֹת הַעֲבָרַת זְמַן עֲדַיִן")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Rows

    private func pendingRow(_ t: TimeTransfer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(headline(t))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Button { transfers.reject(t) } label: {
                    Text("דְּחֵה")
                        .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                Button { transfers.approve(t) } label: {
                    Text("אַשֵּׁר ✅")
                        .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(AppColor.successMint, in: Capsule())
                }
                .buttonStyle(.plain)
                Text(t.isGift ? "🎁 חִנָּם" : "💎 \(t.diamondPrice)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).fill(.white.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private func historyRow(_ t: TimeTransfer) -> some View {
        HStack(spacing: 10) {
            Text(statusEmoji(t.status)).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(headline(t))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(statusText(t.status))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(t.isGift ? "🎁" : "💎\(t.diamondPrice)")
                .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, AppSpacing.md).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous).fill(.white.opacity(0.06)))
    }

    // MARK: - Copy

    private func headline(_ t: TimeTransfer) -> String {
        t.isGift
            ? "\(t.fromName) נוֹתֵן \(t.minutes) דַּקּוֹת לְ\(t.toName)"
            : "\(t.toName) קוֹנֶה \(t.minutes) דַּקּוֹת מֵ\(t.fromName)"
    }

    private func statusEmoji(_ s: TimeTransfer.Status) -> String {
        switch s {
        case .pendingSeller:    return "⏳"
        case .pendingParent:    return "⏳"
        case .approved:         return "✅"
        case .completed:        return "🎉"
        case .declinedBySeller: return "🙅"
        case .rejected:         return "🚫"
        case .canceled:         return "↩️"
        case .failed:           return "⚠️"
        }
    }

    private func statusText(_ s: TimeTransfer.Status) -> String {
        switch s {
        case .pendingSeller:    return "מַמְתִּינָה לָאָח"
        case .pendingParent:    return "מַמְתִּינָה לְאִשּׁוּר"
        case .approved:         return "אֻשַּׁר — בְּהַעֲבָרָה"
        case .completed:        return "הוּשְׁלַם"
        case .declinedBySeller: return "הָאָח לֹא הִסְכִּים"
        case .rejected:         return "נִדְחָה"
        case .canceled:         return "בֻּטַּל"
        case .failed:           return "לֹא הִסְתַּדֵּר"
        }
    }
}
