import Foundation

struct Question: Identifiable, Equatable {
    let id = UUID()
    let topic: Topic
    let prompt: String
    let options: [String]
    let correctIndex: Int
    /// What to read aloud. For visual (early-reader) questions the on-screen
    /// `prompt` is pictures, so the spoken instruction lives here. nil → speak
    /// the prompt itself.
    var spoken: String? = nil

    var correctAnswer: String { options[correctIndex] }
    /// The line the read-aloud / auto-read should speak.
    var readAloudText: String { spoken ?? prompt }
}
