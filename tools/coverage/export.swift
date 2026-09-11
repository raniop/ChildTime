import Foundation

// 📊 The dashboard's "כיסוי לפי כיתה" data, straight from the banks in the app.
//
// Compiled together with the real bank files by export.sh — no simulator, no
// XCTest, ~10 seconds — so it can run on every commit that touches a bank and
// the dashboard never shows yesterday's numbers again.

// The banks reach for a few app singletons at runtime; none of them matter for
// counting, so they get inert stand-ins here.
final class ProfileStore { static let shared = ProfileStore(); var activeID: UUID? = nil }
enum WorldPasses { static let all: [QuestionPack] = []; static func find(_ id: String) -> QuestionPack? { nil } }

@main
struct CoverageExport {
    /// Mirrors QuestionGenerator.minGradePool: below this a grade is topped up
    /// from neighbouring grades.
    static let minGradePool = 30

    static func main() throws {
        guard CommandLine.arguments.count > 1 else {
            FileHandle.standardError.write("usage: coverage <out.json>\n".data(using: .utf8)!)
            exit(2)
        }
        var topicsOut: [[String: Any]] = []
        for topic in Topic.allCases {
            var row: [String: Any] = [
                "topic": topic.rawValue,
                "label": topic.displayName,
                "emoji": topic.emoji,
                "pack": topic.pack != nil,
                "minGrade": WorldSuitability.minGrade(for: topic),
            ]
            switch topic {
            case .math:
                // Generated per question by CurriculumMath — there is no bank to run out of.
                row["computed"] = true
                row["total"] = 0
                row["grades"] = (0...8).map { ["grade": $0, "tagged": 0, "pool": 0] }
            case .reading:
                let passages = ReadingContent.passages
                row["total"] = passages.reduce(0) { $0 + $1.questions.count }
                row["passages"] = passages.count
                row["grades"] = (0...8).map { g -> [String: Any] in
                    let inWindow = passages.filter { $0.gradeWindow.contains(g) }
                    let q = inWindow.reduce(0) { $0 + $1.questions.count }
                    return ["grade": g, "tagged": q, "pool": q, "passages": inWindow.count]
                }
            default:
                guard let bank = QuestionBanks.builtInBank(for: topic), !bank.isEmpty else { continue }
                row["total"] = bank.count
                var tiers: [String: Int] = [:]
                for q in bank { tiers[q.difficulty.rawValue, default: 0] += 1 }
                row["tiers"] = tiers
                row["grades"] = (0...8).map { g -> [String: Any] in
                    let tagged = bank.filter { $0.grades.contains(g) }.count
                    return ["grade": g, "tagged": tagged, "pool": max(tagged, min(minGradePool, bank.count))]
                }
            }
            // 🇺🇸 The English (US) catalog, counted the same way — hidden in the app
            // until a world has at least ContentAvailability.minimumBank questions.
            switch topic {
            case .math: row["en"] = ["computed": true]
            case .reading:
                let passages = EnglishContent.passages
                row["en"] = ["total": passages.reduce(0) { $0 + $1.questions.count }, "passages": passages.count,
                             "grades": (0...8).map { g -> [String: Any] in
                                 let inWindow = passages.filter { $0.gradeWindow.contains(g) }
                                 return ["grade": g, "tagged": inWindow.reduce(0) { $0 + $1.questions.count }, "passages": inWindow.count]
                             }]
            default:
                let bank = EnglishContent.bank(for: topic)
                row["en"] = ["total": bank.count,
                             "grades": (0...8).map { g in ["grade": g, "tagged": bank.filter { $0.grades.contains(g) }.count] }]
            }
            topicsOut.append(row)
        }
        let payload: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "minGradePool": minGradePool,
            "target": 200,
            "topics": topicsOut,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("📊 \(topicsOut.count) worlds → \(CommandLine.arguments[1])")
    }
}
