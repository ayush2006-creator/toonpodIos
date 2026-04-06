import Foundation

struct CommunityGame: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let tags: [String]
    let creatorId: String
    let creatorName: String
    let isPublic: Bool
    let shareCode: String
    let questions: [Question]
    let playCount: Int
    let totalRating: Int
    let ratingCount: Int
    let createdAt: Date
    let updatedAt: Date

    var averageRating: Double {
        ratingCount > 0 ? Double(totalRating) / Double(ratingCount) : 0
    }
}

struct CommunityGamePlay: Codable {
    let gameId: String
    let userId: String
    let rating: Int
    let winnings: Int
    let correct: Int
    let playedAt: Date
}

struct CommunityQuestionType: Identifiable {
    let id = UUID()
    let value: QuestionType
    let label: String
    let description: String
}

let communityQuestionTypes: [CommunityQuestionType] = [
    .init(value: .fourOptions, label: "Multiple Choice", description: "4 options, 1 correct answer"),
    .init(value: .whichIs, label: "Which Is?", description: "Binary choice between two things"),
    .init(value: .beforeAfterBinary, label: "Before or After?", description: "Did X happen before or after Y?"),
    .init(value: .oddOneOut, label: "Odd One Out", description: "4 items, find the one that doesn't belong"),
    .init(value: .wipeout, label: "Wipeout", description: "Multiple options, select all correct ones"),
    .init(value: .lightning, label: "Lightning Round", description: "6 rapid-fire binary questions"),
]

let maxCommunityGames = 100
let questionsPerGame = 15
let minQuestionsRequired = 1
