import SwiftUI

/// 🧹 Parent-side chores management for ONE child (opened from the child card):
/// approve/return what the kid marked done, see the money pocket and settle it,
/// add/remove chores. Sits behind the parent gate like the rest of the dashboard.
struct ChoresParentView: View {
    let profile: Profile
    @StateObject private var choreStore = ChoreStore.shared
    @StateObject private var remote = RemoteSyncManager.shared
    @Environment(\.dismiss) private var dismiss

    // New-chore form.
    @State private var newTitle = ""
    @State private var newEmoji = "🧹"
    @State private var newMinutes = 15
    @State private var newCoins = 0
    @State private var newDaily = true
    @State private var settleConfirm = false

    private static let emojiOptions = ["🧹", "🛏", "🍽", "🗑", "👕", "🐕", "🪴", "🎒", "🧸", "🛒"]

    private var myChores: [Chore] { choreStore.chores(forChild: profile.id) }
    private var pending: [Chore] { myChores.filter { $0.isPendingApproval } }
    private var rest: [Chore] { myChores.filter { !$0.isPendingApproval } }

    /// 🪙 what the family owes the kid right now (synced pocket + in-flight).
    private var moneyBalance: Int {
        max(0, (remote.remoteSnapshots[profile.id]?.moneyCoins ?? 0)
            + remote.pendingMoney[profile.id, default: 0])
    }

    var body: some View {
        NavigationStack {
            Form {
                if !pending.isEmpty {
                    Section("מחכה לאישור שלכם 🕐") {
                        ForEach(pending) { chore in pendingRow(chore) }
                    }
                }

                Section("קופת הכסף 🪙") {
                    HStack {
                        Text("\(profile.name) \(profile.gender == .girl ? "צברה" : "צבר")")
                        Spacer()
                        Text("₪\(moneyBalance)")
                            .font(.system(.body, design: .rounded)).bold()
                            .foregroundStyle(moneyBalance > 0 ? .orange : .secondary)
                    }
                    if moneyBalance > 0 {
                        Button("שילמתי ביד — אפסו את הקופה ✅") { settleConfirm = true }
                            .confirmationDialog("נתתם ל\(profile.name) ₪\(moneyBalance) ביד?",
                                                isPresented: $settleConfirm, titleVisibility: .visible) {
                                Button("כן, שילמתי — אפסו") {
                                    choreStore.settleMoney(childID: profile.id, amount: moneyBalance)
                                    Haptic.success()
                                }
                                Button("ביטול", role: .cancel) {}
                            }
                    } else {
                        Text("כשמאשרים מטלה עם פרס כסף — הסכום נרשם כאן, ואתם נותנים ביד.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("המטלות של \(profile.name)") {
                    if rest.isEmpty {
                        Text("עוד אין מטלות — הוסיפו למטה את הראשונה 👇")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(rest) { chore in choreRow(chore) }
                        .onDelete { idx in
                            idx.map { rest[$0] }.forEach { choreStore.deleteChore($0) }
                        }
                }

                Section("מטלה חדשה ➕") {
                    RTLTextField(placeholder: "מה המטלה? (למשל: לסדר את החדר)", text: $newTitle)
                        .frame(height: 24)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.emojiOptions, id: \.self) { e in
                                Button {
                                    newEmoji = e
                                } label: {
                                    Text(e).font(.system(size: 26))
                                        .frame(width: 40, height: 40)
                                        .background(newEmoji == e ? Color.accentColor.opacity(0.25) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Stepper("⏰ פרס דקות משחק: \(newMinutes)", value: $newMinutes, in: 0...120, step: 5)
                    Stepper("🪙 פרס כסף: ₪\(newCoins)", value: $newCoins, in: 0...100)
                    Toggle("חוזרת כל יום 🔁", isOn: $newDaily)
                    Text("הילד/ה בוחרים בעצמם איזה פרס לקבל — דקות או כסף. פרס על 0 לא יוצע.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        choreStore.addChore(childID: profile.id,
                                            title: newTitle.trimmingCharacters(in: .whitespaces),
                                            emoji: newEmoji,
                                            rewardMinutes: newMinutes,
                                            rewardCoins: newCoins,
                                            isDaily: newDaily)
                        newTitle = ""
                        Haptic.success()
                    } label: {
                        HStack { Spacer(); Text("הוסיפו מטלה").bold(); Spacer() }
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || (newMinutes == 0 && newCoins == 0))
                }
            }
            .navigationTitle("מטלות הבית · \(profile.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("סגור") { dismiss() } }
            }
            .onAppear { choreStore.startIfNeeded() }
        }
    }

    @ViewBuilder
    private func pendingRow(_ chore: Chore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(chore.emoji) \(chore.title)").bold()
                Spacer()
                Text(chore.chosenReward == "coins"
                     ? "🪙 ביקש/ה ₪\(chore.rewardCoins)"
                     : "⏰ ביקש/ה \(chore.rewardMinutes) דק׳")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button {
                    choreStore.approve(chore)
                    Haptic.success()
                } label: {
                    Text("בוצע — אשרו ✅").bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Button {
                    choreStore.returnChore(chore)
                    Haptic.light()
                } label: {
                    Text("עוד לא הושלמה")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .buttonStyle(.borderless)   // keep Form from hijacking row taps
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func choreRow(_ chore: Chore) -> some View {
        HStack {
            Text(chore.emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                HStack(spacing: 6) {
                    if chore.rewardMinutes > 0 { Text("⏰ \(chore.rewardMinutes) דק׳") }
                    if chore.rewardCoins > 0 { Text("🪙 ₪\(chore.rewardCoins)") }
                    if chore.isDaily { Text("🔁 יומית") }
                    if chore.isDaily && chore.approvedToday { Text("✅ אושרה היום") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
