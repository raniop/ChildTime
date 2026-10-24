import Foundation
import Testing
@testable import ChildTime

/// 🔎 The parent's search (Rani, 2026-10-24): what a parent really types must
/// put the right page FIRST.
struct ParentSearchTests {
    private let dana = Profile(name: "דָּנָה", gender: .girl)
    private var all: [ParentSearchEntry] { ParentSearch.entries(children: [dana]) }
    private func first(_ q: String) -> ParentSearchTarget? { ParentSearch.search(q, in: all).first?.target }

    @Test func parentCode() {
        #expect(first("איך אני משנה את הקוד הורה") == .settings(.pin))
        #expect(first("שכחתי סיסמה") == .settings(.pin))
        #expect(first("how do I change the parent code") == .settings(.pin))
    }

    @Test func childPages() {
        #expect(first("שעת שינה") == .childPage(.bedtime, dana.id))
        #expect(first("איך משנים את רמת הקושי") == .childPage(.difficulty, dana.id))
        #expect(first("כמה זמן מסך ביום") == .childPage(.screentime, dana.id))
        #expect(first("בית ספר") == .childPage(.school, dana.id))
        #expect(first("screen time") == .childPage(.screentime, dana.id))
    }

    @Test func actions() {
        #expect(first("לתת לדנה דקות מתנה") == .gift(dana.id))
        #expect(first("לנעול את הטלפון") == .actions(dana.id))
        #expect(first("מצב טיסה") == .actions(dana.id))
        #expect(first("מטלות") == .chores)
        #expect(first("להוסיף הורה נוסף") == .settings(.family))
    }

    @Test func prefixesAndTypos() {
        #expect(first("ובשעת השינה") == .childPage(.bedtime, dana.id))   // ו + ב peeled
        #expect(first("סיסמא") == .settings(.pin))
        #expect(first("התרעות") == .settings(.notifications))             // one letter off
    }

    @Test func nothingForNoise() {
        #expect(ParentSearch.search("איך אני", in: all).isEmpty)
        #expect(ParentSearch.search("   ", in: all).isEmpty)
    }
}
