import Foundation

/// Decides when special events fire during a question session.
enum EventEngine {
    /// Mystery Portal — appears on a random question, ~10% chance, but not on Q1 or Q2.
    static func shouldFireMysteryPortal(questionIndex: Int, totalQuestions: Int) -> Bool {
        guard questionIndex >= 2 && questionIndex < totalQuestions - 1 else { return false }
        return Double.random(in: 0...1) < 0.10
    }

    /// Super Question — golden frame, x3 reward. ~7% chance.
    static func shouldFireSuperQuestion(questionIndex: Int, totalQuestions: Int) -> Bool {
        guard questionIndex >= 1 && questionIndex < totalQuestions else { return false }
        return Double.random(in: 0...1) < 0.07
    }

    /// Big combo celebration trigger — fires at exactly 3 and 5 in a row.
    static func shouldFireComboEvent(streak: Int) -> Bool {
        streak == 3 || streak == 5 || streak == 10
    }
}
