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
    case elimination = "elimination"
}

// MARK: - Question Data

struct QuestionData: Codable {

    // ── Shared ────────────────────────────────────────────────────────────────
    /// Primary question text (most types use this)
    var query: String?
    /// Alternate question text field used by some backend types
    var question: String?
    /// Free-text interesting fact shown after answer reveal
    var interestingFact: String?
    /// Hint text (shown when hint lifeline is used)
    var hint: String?
    /// Category label
    var category: String?
    /// Jeopardy-style category
    var jeopardyCategory: String?

    // ── 4_options / picture_choice ────────────────────────────────────────────
    /// Multiple-choice option A (backend key: option_a)
    var optionA: String?
    /// Multiple-choice option B (backend key: option_b)
    var optionB: String?
    /// Multiple-choice option C (backend key: option_c)
    var optionC: String?
    /// Multiple-choice option D (backend key: option_d)
    var optionD: String?
    /// The correct option label/text (backend key: correct_option)
    var correctOption: String?

    // ── which_is / before_after_binary / fill_4th / odd_one_out / chain ───────
    /// Generic correct answer text (backend key: correct_answer)
    var correctAnswer: String?
    /// What links the items together (odd_one_out, fill_4th)
    var connection: String?

    // ── odd_one_out / fill_4th (no-underscore numbered options) ──────────────
    // Backend sends "option1" … "option4" (no underscore) for these types.
    // wipeout / chains use "option_1"…"option_9" (underscore) → captured in numberedOptions.
    var option1: String?
    var option2: String?
    var option3: String?
    var option4: String?

    // ── before_after_chain ────────────────────────────────────────────────────
    /// Pipe-separated correct ordering of chain items (backend key: correct_sequence)
    var correctSequence: String?

    // ── wipeout ───────────────────────────────────────────────────────────────
    /// Pipe-separated correct options for wipeout (backend key: correct_options)
    var correctOptions: String?
    /// All numbered options 1-9 decoded from dynamic "option_1"…"option_9" keys.
    /// Used by wipeout (up to 9) and before_after_chain (variable length).
    var numberedOptions: [String] = []

    // ── fill_4th ──────────────────────────────────────────────────────────────
    /// Pipe-separated given items in the group (backend key: given_options)
    var givenOptions: String?

    // ── lightning ─────────────────────────────────────────────────────────────
    /// Pipe-separated sub-questions (backend key: questions)
    var questions: String?
    /// Pipe-separated question types for each sub-question (backend key: question_types)
    var questionTypes: String?
    /// Pipe-separated correct answers for each sub-question (backend key: correct_answers)
    var correctAnswers: String?
    /// Pipe-separated interesting facts for each sub-question (backend key: interesting_facts)
    var interestingFacts: String?

    // ── guess_the_picture ─────────────────────────────────────────────────────
    /// Progressive reveal clues (decoded as JSON array)
    var clues: [String]?
    /// Name/answer for guess_the_picture (backend key: name)
    var name: String?
    /// URL slug for picture lookup
    var slug: String?

    // ── elimination ───────────────────────────────────────────────────────────
    /// Pipe-or-comma-separated sample correct answers (backend key: sample_answers)
    var sampleAnswers: String?

    // ── misc ──────────────────────────────────────────────────────────────────
    var interactiveQ: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case query, question, connection, hint, name, slug, clues, category
        case correctAnswer      = "correct_answer"
        case correctOption      = "correct_option"
        case optionA            = "option_a"
        case optionB            = "option_b"
        case optionC            = "option_c"
        case optionD            = "option_d"
        // odd_one_out and fill_4th send "option1"…"option4" (no underscore)
        // wipeout/chain send "option_1"…"option_9" (underscore) — captured by numberedOptions
        case option1            = "option1"
        case option2            = "option2"
        case option3            = "option3"
        case option4            = "option4"
        case interestingFact    = "interesting_fact"
        case sampleAnswers      = "sample_answers"
        case correctOptions     = "correct_options"
        case givenOptions       = "given_options"
        case correctSequence    = "correct_sequence"
        case questions
        case questionTypes      = "question_types"
        case correctAnswers     = "correct_answers"
        case interestingFacts   = "interesting_facts"
        case jeopardyCategory   = "jeopardy_category"
        case interactiveQ
    }

    // Dynamic key struct for option_1 … option_9
    struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    // MARK: - Decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        query           = try c.decodeIfPresent(String.self, forKey: .query)
        question        = try c.decodeIfPresent(String.self, forKey: .question)
        correctAnswer   = try c.decodeIfPresent(String.self, forKey: .correctAnswer)
        correctOption   = try c.decodeIfPresent(String.self, forKey: .correctOption)
        optionA         = try c.decodeIfPresent(String.self, forKey: .optionA)
        optionB         = try c.decodeIfPresent(String.self, forKey: .optionB)
        optionC         = try c.decodeIfPresent(String.self, forKey: .optionC)
        optionD         = try c.decodeIfPresent(String.self, forKey: .optionD)
        option1         = try c.decodeIfPresent(String.self, forKey: .option1)
        option2         = try c.decodeIfPresent(String.self, forKey: .option2)
        option3         = try c.decodeIfPresent(String.self, forKey: .option3)
        option4         = try c.decodeIfPresent(String.self, forKey: .option4)
        connection      = try c.decodeIfPresent(String.self, forKey: .connection)
        interestingFact = try c.decodeIfPresent(String.self, forKey: .interestingFact)
        hint            = try c.decodeIfPresent(String.self, forKey: .hint)
        sampleAnswers   = try c.decodeIfPresent(String.self, forKey: .sampleAnswers)
        correctOptions  = try c.decodeIfPresent(String.self, forKey: .correctOptions)
        givenOptions    = try c.decodeIfPresent(String.self, forKey: .givenOptions)
        correctSequence = try c.decodeIfPresent(String.self, forKey: .correctSequence)
        questions       = try c.decodeIfPresent(String.self, forKey: .questions)
        questionTypes   = try c.decodeIfPresent(String.self, forKey: .questionTypes)
        correctAnswers  = try c.decodeIfPresent(String.self, forKey: .correctAnswers)
        interestingFacts = try c.decodeIfPresent(String.self, forKey: .interestingFacts)
        category        = try c.decodeIfPresent(String.self, forKey: .category)
        jeopardyCategory = try c.decodeIfPresent(String.self, forKey: .jeopardyCategory)
        name            = try c.decodeIfPresent(String.self, forKey: .name)
        slug            = try c.decodeIfPresent(String.self, forKey: .slug)
        clues           = try c.decodeIfPresent([String].self, forKey: .clues)
        interactiveQ    = try c.decodeIfPresent(String.self, forKey: .interactiveQ)

        // Decode "option_1" … "option_9" into numberedOptions array.
        // option1-4 are also decoded individually above (for oddOneOut / chain).
        // numberedOptions covers all of them plus 5-9 (for wipeout / long chains).
        let dyn = try decoder.container(keyedBy: DynamicKey.self)
        var opts: [String] = []
        for i in 1...9 {
            if let val = try dyn.decodeIfPresent(String.self, forKey: DynamicKey(stringValue: "option_\(i)")!) {
                opts.append(val)
            } else {
                break // stop at first gap — options are sequential
            }
        }
        numberedOptions = opts
    }

    // MARK: - Encoding

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(query,            forKey: .query)
        try c.encodeIfPresent(question,         forKey: .question)
        try c.encodeIfPresent(correctAnswer,    forKey: .correctAnswer)
        try c.encodeIfPresent(correctOption,    forKey: .correctOption)
        try c.encodeIfPresent(optionA,          forKey: .optionA)
        try c.encodeIfPresent(optionB,          forKey: .optionB)
        try c.encodeIfPresent(optionC,          forKey: .optionC)
        try c.encodeIfPresent(optionD,          forKey: .optionD)
        try c.encodeIfPresent(option1,          forKey: .option1)
        try c.encodeIfPresent(option2,          forKey: .option2)
        try c.encodeIfPresent(option3,          forKey: .option3)
        try c.encodeIfPresent(option4,          forKey: .option4)
        try c.encodeIfPresent(connection,       forKey: .connection)
        try c.encodeIfPresent(interestingFact,  forKey: .interestingFact)
        try c.encodeIfPresent(hint,             forKey: .hint)
        try c.encodeIfPresent(sampleAnswers,    forKey: .sampleAnswers)
        try c.encodeIfPresent(correctOptions,   forKey: .correctOptions)
        try c.encodeIfPresent(givenOptions,     forKey: .givenOptions)
        try c.encodeIfPresent(correctSequence,  forKey: .correctSequence)
        try c.encodeIfPresent(questions,        forKey: .questions)
        try c.encodeIfPresent(questionTypes,    forKey: .questionTypes)
        try c.encodeIfPresent(correctAnswers,   forKey: .correctAnswers)
        try c.encodeIfPresent(interestingFacts, forKey: .interestingFacts)
        try c.encodeIfPresent(category,         forKey: .category)
        try c.encodeIfPresent(jeopardyCategory, forKey: .jeopardyCategory)
        try c.encodeIfPresent(name,             forKey: .name)
        try c.encodeIfPresent(slug,             forKey: .slug)
        try c.encodeIfPresent(clues,            forKey: .clues)
        try c.encodeIfPresent(interactiveQ,     forKey: .interactiveQ)
    }

    init() {}

    // MARK: - Computed Helpers

    /// Splits a pipe-separated string into a trimmed, non-empty array.
    private func pipeSplit(_ s: String?) -> [String] {
        guard let s, !s.isEmpty else { return [] }
        return s.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
    }

    // lightning round — all fields are pipe-separated parallel arrays
    var lightningQuestions:    [String] { pipeSplit(questions) }
    var lightningAnswers:      [String] { pipeSplit(correctAnswers) }
    var lightningTypes:        [String] { pipeSplit(questionTypes) }
    var lightningFacts:        [String] { pipeSplit(interestingFacts) }

    // before_after_chain — correct ordering is pipe-separated
    var chainSequence:         [String] { pipeSplit(correctSequence) }

    // wipeout — correct options is pipe-separated
    var wipeoutCorrectList:    [String] { pipeSplit(correctOptions) }

    // fill_4th — given items may be pipe-separated
    var givenOptionsList:      [String] { pipeSplit(givenOptions) }

    // elimination — sample answers pipe- or comma-separated
    var sampleAnswersList: [String] {
        guard let s = sampleAnswers, !s.isEmpty else { return [] }
        let pipe = pipeSplit(s)
        if pipe.count > 1 { return pipe }
        return s.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
    }

    // closest_number / hidden_timer — correct answer is a numeric string
    var targetNumber: Double? {
        guard let s = correctAnswer else { return nil }
        return Double(s)
    }

    // which_is fallback — parse options embedded in query text: "…: optA or optB?"
    var whichIsOptionsFromQuery: [String] {
        let text = query ?? question ?? ""
        guard let colonIdx = text.firstIndex(of: ":") else { return [] }
        let after = String(text[text.index(after: colonIdx)...])
                        .replacingOccurrences(of: "?", with: "")
                        .trimmingCharacters(in: .whitespaces)
        let parts = after.components(separatedBy: " or ")
                         .map { $0.trimmingCharacters(in: .whitespaces) }
                         .filter { !$0.isEmpty }
        return parts.count == 2 ? parts : []
    }
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
    let loginStreakBonus: Int
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
    let loginStreakBonus: Int
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
