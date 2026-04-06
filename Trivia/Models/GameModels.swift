import Foundation

// MARK: - Question Types

enum QuestionType: String, Codable, CaseIterable {
    case whichIs = "which_is"
    case beforeAfterBinary = "before_after_binary"
    case fourOptions = "4_options"
    case fill4th = "fill_4th"
    case oddOneOut = "odd_one_out"
    case wipeout = "wipeout"
    case beforeAfterChain = "before_after_chain"
    case lightning = "lightning"
    case guessThePicture = "guess_the_picture"
    case hiddenTimer = "hidden_timer"
    case closestNumber = "closest_number"
    case pictureChoice = "picture_choice"
}

// MARK: - Question Data
// Uses custom decoding to handle dynamic keys like option_1 through option_9

struct QuestionData: Codable {
    var query: String?
    var question: String?
    var correctAnswer: String?
    var correctOption: String?
    var optionA: String?
    var optionB: String?
    var optionC: String?
    var optionD: String?
    var option1: String?
    var option2: String?
    var option3: String?
    var option4: String?
    var connection: String?
    var interestingFact: String?
    var hint: String?
    var sampleAnswers: String?
    var correctOptions: String?
    var givenOptions: String?
    var correctSequence: String?
    var questions: String?
    var questionTypes: String?
    var correctAnswers: String?
    var interestingFacts: String?
    var category: String?
    var jeopardyCategory: String?
    var name: String?
    var slug: String?
    var clues: [String]?
    var interactiveQ: String?

    /// Wipeout dynamic options (option_1 through option_9)
    var wipeoutOptions: [String] = []

    /// All extra keys not explicitly modeled
    var extraFields: [String: String] = [:]

    // Known keys for standard Codable
    enum CodingKeys: String, CodingKey {
        case query, question, connection, hint, name, slug, clues, category
        case correctAnswer = "correct_answer"
        case correctOption = "correct_option"
        case optionA = "option_a"
        case optionB = "option_b"
        case optionC = "option_c"
        case optionD = "option_d"
        case option1, option2, option3, option4
        case interestingFact = "interesting_fact"
        case sampleAnswers = "sample_answers"
        case correctOptions = "correct_options"
        case givenOptions = "given_options"
        case correctSequence = "correct_sequence"
        case questions
        case questionTypes = "question_types"
        case correctAnswers = "correct_answers"
        case interestingFacts = "interesting_facts"
        case jeopardyCategory = "jeopardy_category"
        case interactiveQ
    }

    // Dynamic key for option_1 through option_9
    struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        // Decode known keys
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decodeIfPresent(String.self, forKey: .query)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        correctAnswer = try container.decodeIfPresent(String.self, forKey: .correctAnswer)
        correctOption = try container.decodeIfPresent(String.self, forKey: .correctOption)
        optionA = try container.decodeIfPresent(String.self, forKey: .optionA)
        optionB = try container.decodeIfPresent(String.self, forKey: .optionB)
        optionC = try container.decodeIfPresent(String.self, forKey: .optionC)
        optionD = try container.decodeIfPresent(String.self, forKey: .optionD)
        option1 = try container.decodeIfPresent(String.self, forKey: .option1)
        option2 = try container.decodeIfPresent(String.self, forKey: .option2)
        option3 = try container.decodeIfPresent(String.self, forKey: .option3)
        option4 = try container.decodeIfPresent(String.self, forKey: .option4)
        connection = try container.decodeIfPresent(String.self, forKey: .connection)
        interestingFact = try container.decodeIfPresent(String.self, forKey: .interestingFact)
        hint = try container.decodeIfPresent(String.self, forKey: .hint)
        sampleAnswers = try container.decodeIfPresent(String.self, forKey: .sampleAnswers)
        correctOptions = try container.decodeIfPresent(String.self, forKey: .correctOptions)
        givenOptions = try container.decodeIfPresent(String.self, forKey: .givenOptions)
        correctSequence = try container.decodeIfPresent(String.self, forKey: .correctSequence)
        questions = try container.decodeIfPresent(String.self, forKey: .questions)
        questionTypes = try container.decodeIfPresent(String.self, forKey: .questionTypes)
        correctAnswers = try container.decodeIfPresent(String.self, forKey: .correctAnswers)
        interestingFacts = try container.decodeIfPresent(String.self, forKey: .interestingFacts)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        jeopardyCategory = try container.decodeIfPresent(String.self, forKey: .jeopardyCategory)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        clues = try container.decodeIfPresent([String].self, forKey: .clues)
        interactiveQ = try container.decodeIfPresent(String.self, forKey: .interactiveQ)

        // Decode dynamic keys: option_1 through option_9
        let dynamicContainer = try decoder.container(keyedBy: DynamicKey.self)
        var opts: [String] = []
        for i in 1...9 {
            let key = DynamicKey(stringValue: "option_\(i)")!
            if let val = try dynamicContainer.decodeIfPresent(String.self, forKey: key) {
                opts.append(val)
            }
        }
        wipeoutOptions = opts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(query, forKey: .query)
        try container.encodeIfPresent(question, forKey: .question)
        try container.encodeIfPresent(correctAnswer, forKey: .correctAnswer)
        try container.encodeIfPresent(correctOption, forKey: .correctOption)
        try container.encodeIfPresent(optionA, forKey: .optionA)
        try container.encodeIfPresent(optionB, forKey: .optionB)
        try container.encodeIfPresent(optionC, forKey: .optionC)
        try container.encodeIfPresent(optionD, forKey: .optionD)
        try container.encodeIfPresent(option1, forKey: .option1)
        try container.encodeIfPresent(option2, forKey: .option2)
        try container.encodeIfPresent(option3, forKey: .option3)
        try container.encodeIfPresent(option4, forKey: .option4)
        try container.encodeIfPresent(connection, forKey: .connection)
        try container.encodeIfPresent(interestingFact, forKey: .interestingFact)
        try container.encodeIfPresent(hint, forKey: .hint)
        try container.encodeIfPresent(sampleAnswers, forKey: .sampleAnswers)
        try container.encodeIfPresent(correctOptions, forKey: .correctOptions)
        try container.encodeIfPresent(givenOptions, forKey: .givenOptions)
        try container.encodeIfPresent(correctSequence, forKey: .correctSequence)
        try container.encodeIfPresent(questions, forKey: .questions)
        try container.encodeIfPresent(questionTypes, forKey: .questionTypes)
        try container.encodeIfPresent(correctAnswers, forKey: .correctAnswers)
        try container.encodeIfPresent(interestingFacts, forKey: .interestingFacts)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(jeopardyCategory, forKey: .jeopardyCategory)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encodeIfPresent(clues, forKey: .clues)
        try container.encodeIfPresent(interactiveQ, forKey: .interactiveQ)
    }

    init() {}
}

// MARK: - Question

struct Question: Codable, Identifiable {
    var id = UUID()
    var type: QuestionType
    var position: Int?
    var difficulty: Int?
    var data: QuestionData
    var question: String?
    var images: [String]?
    var hints: [String]?
    var options: [String]?
    var answer: String?
    var interestingFact: String?
    var category: String?

    enum CodingKeys: String, CodingKey {
        case type, position, difficulty, data, question, images, hints, options, answer, category
        case interestingFact = "interesting_fact"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        type = try container.decode(QuestionType.self, forKey: .type)
        position = try container.decodeIfPresent(Int.self, forKey: .position)
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty)
        data = try container.decode(QuestionData.self, forKey: .data)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        hints = try container.decodeIfPresent([String].self, forKey: .hints)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        answer = try container.decodeIfPresent(String.self, forKey: .answer)
        interestingFact = try container.decodeIfPresent(String.self, forKey: .interestingFact)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }

    /// The display text for this question
    var displayText: String {
        data.query ?? data.question ?? question ?? ""
    }
}

// MARK: - Game Result

struct GameResult: Identifiable {
    let id = UUID()
    let correct: Bool
    let totalPrize: Int
    let basePrize: Int
    let speedBonus: Int
    let streakBonus: Int
    let timeTaken: Double
    let type: QuestionType
    let position: Int?
    let ladderPrize: Int
    let scoredBy: String?
}

// MARK: - Finish Question Result

struct FinishQuestionResult {
    let isCorrect: Bool
    let totalPrize: Int
    let speedBonus: Int
    let streakBonus: Int
    let fact: String
    let elapsed: Double
}

// MARK: - Finish Question Options

struct FinishQuestionOptions {
    var overridePrize: Int?
    var prizeMultiplier: Double?
    var skipTimer: Bool = false
    var selectedText: String?
}

// MARK: - Score Data

struct ScoreData: Codable {
    let level: Int
    let winnings: Int
    let correct: Int
    let totalQs: Int
    let maxStreak: Int
    let gameMode: String
}

// MARK: - Ranking Entry

struct RankingEntry: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let totalWinnings: Int
    let gamesPlayed: Int
    var sparks: Int?
}

// MARK: - Party Player

struct PartyPlayer: Identifiable, Codable {
    let id: Int
    let faceId: Int
    let name: String
    var score: Int
}

// MARK: - Lifelines

struct Lifelines {
    var fiftyFifty: Bool = true
    var hint: Bool = true
    var swap: Bool = true
}

// MARK: - Feedback Data

struct FeedbackData {
    let isCorrect: Bool
    let totalPrize: Int
    let speedBonus: Int
    let streakBonus: Int
    let fact: String
}

// MARK: - API Responses

struct QuestionsResponse: Codable {
    let questions: [Question]
    let setId: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questions = try container.decode([Question].self, forKey: .questions)
        setId = try container.decodeIfPresent(String.self, forKey: .setId)
    }

    enum CodingKeys: String, CodingKey {
        case questions
        case setId
    }
}

struct HealthResponse: Codable {
    let status: String?
    let capabilities: [String: Bool]?
}

struct MatchAnswerResponse: Codable {
    let match: String?
}

struct GenerateQuestionResponse: Codable {
    let question: Question?
}

struct TTSResponse {
    let audioData: Data
}

/// Response from /api/speak — Inworld TTS with word-level timestamps for lip-sync
struct SpeakResponse: Codable {
    /// Base64-encoded audio data (WAV/MP3)
    let audioContent: String
    /// Individual words in the spoken text
    let words: [String]
    /// Start time of each word in milliseconds
    let wtimes: [Int]
    /// Duration of each word in milliseconds
    let wdurations: [Int]

    /// Decoded audio bytes from base64
    var audioData: Data? {
        Data(base64Encoded: audioContent)
    }

    /// Word timing entries for lip-sync animation
    var wordTimings: [WordTiming] {
        zip(words, zip(wtimes, wdurations)).map { word, timing in
            WordTiming(word: word, startMs: timing.0, durationMs: timing.1)
        }
    }
}

/// A single word with its timing information for lip-sync
struct WordTiming: Identifiable {
    let id = UUID()
    let word: String
    /// Start time in milliseconds from audio start
    let startMs: Int
    /// Duration in milliseconds
    let durationMs: Int

    var startSeconds: Double { Double(startMs) / 1000.0 }
    var durationSeconds: Double { Double(durationMs) / 1000.0 }
    var endSeconds: Double { startSeconds + durationSeconds }
}

struct ExplainAnswerResponse: Codable {
    let text: String
}

struct GameRecapResponse: Codable {
    let text: String
}

struct PersonalChatResponse: Codable {
    let text: String
}

struct CheckoutSessionResponse: Codable {
    let url: String?
    let sessionId: String?
}

struct VerifyPaymentResponse: Codable {
    let success: Bool?
    let sparks: Int?
}

struct ChainCommand: Codable {
    let action: String
    let item: String?
    let position: Int?
    let itemA: String?
    let itemB: String?
}

struct Fill4thVerifyResponse: Codable {
    let valid: Bool
    let reason: String
}
