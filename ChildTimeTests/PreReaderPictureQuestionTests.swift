import Testing
import Foundation
@testable import ChildTime

/// 🧠 גן: thinking questions whose answers are all pictures, from the cloud bank.
struct PreReaderPictureQuestionTests {
    private func item(_ prompt: String, _ answer: String, _ wrong: [String], grades: ClosedRange<Int> = 0...0) -> BankQuestion {
        BankQuestion(prompt: prompt, correctAnswer: answer, distractors: wrong, grades: grades)
    }
    private var pictures: [BankQuestion] {
        (0..<10).map { item("🔬\nמָה נִהְיֶה מִמַּיִם שֶׁשָּׂמִים בַּמַּקְפִּיא? \($0)", "🧊", ["🔥", "🌈", "🍃"]) }
    }

    @Test func aQuestionWithWordsInItsAnswersIsNotAPictureQuestion() {
        #expect(PreReaderContent.isPictureOnly(item("🔬\nמָה?", "🧊", ["🔥", "🌈", "🍃"])))
        #expect(PreReaderContent.isPictureOnly(item("🎨\nאֵיזֶה צֶבַע?", "🟢", ["🟣", "🟠", "🔴"])))
        #expect(PreReaderContent.isPictureOnly(item("🕷\nמִי טוֹוֶה קוּרִים?", "🕷️", ["🐜", "🐞", "🐌"])))
        #expect(!PreReaderContent.isPictureOnly(item("🌋\nמַה יּוֹצֵא מֵהַר גַּעַשׁ?", "לָבָה", ["עָנָן", "חוֹל", "מַיִם"])))
        #expect(!PreReaderContent.isPictureOnly(item("🔢\nכַּמָּה?", "3", ["🍎", "🍌", "🍓"])))
        #expect(!PreReaderContent.isPictureOnly(item("🔬\nמָה?", "🧊", ["🔥", "🌈"])))        // three options only
    }

    @Test func onlyKindergartenPictureItemsAreUsed() {
        let words = (0..<10).map { item("🔬\nשְׁאֵלָה \($0)", "לָבָה", ["עָנָן", "חוֹל", "מַיִם"]) }
        let olderKids = (0..<10).map { item("🔬\nשְׁאֵלָה \($0)", "🧊", ["🔥", "🌈", "🍃"], grades: 2...3) }
        #expect(PreReaderContent.pictureQuestion(from: words, topic: .science) == nil)
        #expect(PreReaderContent.pictureQuestion(from: olderKids, topic: .science) == nil)
        #expect(PreReaderContent.pictureQuestion(from: pictures, topic: .science) != nil)
    }

    /// A world with only a handful would repeat them within one round.
    @Test func aThinPoolIsNotUsedYet() {
        #expect(PreReaderContent.pictureQuestion(from: Array(pictures.prefix(PreReaderContent.minPicturePool - 1)), topic: .science) == nil)
        #expect(PreReaderContent.pictureQuestion(from: Array(pictures.prefix(PreReaderContent.minPicturePool)), topic: .science) != nil)
    }

    @Test func theQuestionKeepsItsFourPicturesAndIsReadWithoutThePictureLine() throws {
        for _ in 0..<20 {
            let q = try #require(PreReaderContent.pictureQuestion(from: pictures, topic: .science))
            #expect(Set(q.options) == ["🧊", "🔥", "🌈", "🍃"])
            #expect(q.correctAnswer == "🧊")
            #expect(q.readAloudText.hasPrefix("מָה נִהְיֶה"))
            #expect(!q.readAloudText.contains("🔬"))
            // The card writes the question once and draws the picture under it.
            #expect(q.prompt == "🔬")
        }
        // An item without a picture line is simply its question.
        #expect(PreReaderContent.pictureLine(of: "מִי טוֹוֶה קוּרִים?") == nil)
        #expect(PreReaderContent.pictureLine(of: "🕷️\nמִי טוֹוֶה קוּרִים?") == "🕷️")
        // A picture line that carries the emoji presentation selector is still not spoken.
        #expect(PreReaderContent.spokenText(of: "🕷️\nמִי טוֹוֶה קוּרִים?") == "מִי טוֹוֶה קוּרִים?")
    }
}
