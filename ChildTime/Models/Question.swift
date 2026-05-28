import Foundation

struct Question: Identifiable, Equatable {
    let id = UUID()
    let topic: Topic
    let prompt: String
    let options: [String]
    let correctIndex: Int

    var correctAnswer: String { options[correctIndex] }
}
