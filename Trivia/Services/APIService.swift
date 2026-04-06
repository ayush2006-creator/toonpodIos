import Foundation

actor APIService {
    static let shared = APIService()
    private let baseURL = AppConstants.serverURL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Health

    func fetchHealth() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/api/health")!
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(HealthResponse.self, from: data)
    }

    // MARK: - Questions

    func fetchQuestions(level: Int, category: String, excludeSets: [String] = []) async throws -> QuestionsResponse {
        var components = URLComponents(string: "\(baseURL)/api/questions")!
        components.queryItems = [
            URLQueryItem(name: "level", value: "\(level)"),
            URLQueryItem(name: "category", value: category),
        ]
        if !excludeSets.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "exclude", value: excludeSets.joined(separator: ",")))
        }

        let url = components.url!
        print("[API] GET \(url)")

        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[API] Response: \(status), \(data.count) bytes")

        do {
            let result = try decoder.decode(QuestionsResponse.self, from: data)
            print("[API] Decoded \(result.questions.count) questions OK")
            return result
        } catch {
            // Log the raw JSON on decode failure for debugging
            let raw = String(data: data, encoding: .utf8) ?? "(not UTF8)"
            print("[API] DECODE ERROR: \(error)")
            print("[API] Raw response (first 500 chars): \(String(raw.prefix(500)))")
            throw error
        }
    }

    // MARK: - Generate Question

    func generateQuestion(topic: String, difficulty: Int, type: String, category: String? = nil) async throws -> Question {
        let url = URL(string: "\(baseURL)/api/generate-question")!
        var body: [String: Any] = [
            "topic": topic,
            "difficulty": difficulty,
            "type": type,
        ]
        if let category { body["category"] = category }
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.generationFailed
        }
        return try decoder.decode(Question.self, from: data)
    }

    // MARK: - TTS

    func fetchTTS(text: String, voice: String = "onyx") async throws -> Data {
        let url = URL(string: "\(baseURL)/api/tts")!
        let body: [String: Any] = ["text": text, "voice": voice]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.ttsFailed
        }
        return data
    }

    // MARK: - Speak (Inworld TTS with lip-sync timestamps)

    func speak(text: String) async throws -> SpeakResponse {
        let url = URL(string: "\(baseURL)/api/speak")!
        let body: [String: Any] = ["text": text]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 501 { throw APIError.speakNotConfigured }
            throw APIError.speakFailed
        }
        return try decoder.decode(SpeakResponse.self, from: data)
    }

    // MARK: - Match Answer

    func matchAnswer(transcript: String, options: [String]) async throws -> String? {
        let url = URL(string: "\(baseURL)/api/match-answer")!
        let body: [String: Any] = ["transcript": transcript, "options": options]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let result = try decoder.decode(MatchAnswerResponse.self, from: data)
        return result.match
    }

    // MARK: - Verify Fill 4th

    func verifyFill4th(answer: String, items: [String], connection: String) async throws -> Fill4thVerifyResponse {
        let url = URL(string: "\(baseURL)/api/verify-fill4th")!
        let body: [String: Any] = ["answer": answer, "items": items, "connection": connection]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.verificationFailed
        }
        return try decoder.decode(Fill4thVerifyResponse.self, from: data)
    }

    // MARK: - Parse Chain Command

    func parseChainCommand(transcript: String, items: [String], currentOrder: [String]) async throws -> ChainCommand {
        let url = URL(string: "\(baseURL)/api/parse-chain-command")!
        let body: [String: Any] = [
            "transcript": transcript,
            "items": items,
            "currentOrder": currentOrder,
        ]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return ChainCommand(action: "unknown", item: nil, position: nil, itemA: nil, itemB: nil)
        }
        return try decoder.decode(ChainCommand.self, from: data)
    }

    // MARK: - Explain Answer

    func explainAnswer(questionText: String, userAnswer: String, correctAnswer: String, isCorrect: Bool) async throws -> String {
        let url = URL(string: "\(baseURL)/api/explain-answer")!
        let body: [String: Any] = [
            "questionText": questionText,
            "userAnswer": userAnswer,
            "correctAnswer": correctAnswer,
            "isCorrect": isCorrect,
        ]
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return "" }
        let result = try decoder.decode(ExplainAnswerResponse.self, from: data)
        return result.text
    }

    // MARK: - Personal Chat

    func personalChat(action: String, params: [String: String]) async throws -> String {
        let url = URL(string: "\(baseURL)/api/personal-chat")!
        var body: [String: Any] = ["action": action]
        for (key, value) in params { body[key] = value }
        let request = makePostRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.personalChatFailed
        }
        let result = try decoder.decode(PersonalChatResponse.self, from: data)
        return result.text
    }

    // MARK: - Game Recap

    func fetchGameRecap(stats: [String: Any]) async throws -> String {
        let url = URL(string: "\(baseURL)/api/game-recap")!
        let request = makePostRequest(url: url, body: stats)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.recapFailed
        }
        let result = try decoder.decode(GameRecapResponse.self, from: data)
        return result.text
    }

    // MARK: - Payments

    func createCheckoutSession(pack: String, uid: String, email: String) async throws -> CheckoutSessionResponse {
        let url = URL(string: "\(baseURL)/api/create-checkout-session")!
        let body: [String: Any] = ["pack": pack, "uid": uid, "email": email]
        let request = makePostRequest(url: url, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(CheckoutSessionResponse.self, from: data)
    }

    func verifyPayment(sessionId: String) async throws -> VerifyPaymentResponse? {
        var components = URLComponents(string: "\(baseURL)/api/verify-payment")!
        components.queryItems = [URLQueryItem(name: "session_id", value: sessionId)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let httpResponse = response as? HTTPURLResponse
        if httpResponse?.statusCode == 409 { return nil }
        guard httpResponse?.statusCode == 200 else { return nil }
        return try decoder.decode(VerifyPaymentResponse.self, from: data)
    }

    // MARK: - Precompute Embeddings (fire and forget)

    func precomputeEmbeddings(options: [String]) {
        Task {
            let url = URL(string: "\(baseURL)/api/precompute-embeddings")!
            let request = makePostRequest(url: url, body: ["options": options])
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Helpers

    private func makePostRequest(url: URL, body: [String: Any]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case generationFailed
    case ttsFailed
    case speakFailed
    case speakNotConfigured
    case verificationFailed
    case personalChatFailed
    case recapFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed: return "Question generation failed"
        case .ttsFailed: return "Text-to-speech failed"
        case .speakFailed: return "Inworld TTS failed"
        case .speakNotConfigured: return "Inworld TTS not configured on server"
        case .verificationFailed: return "Verification failed"
        case .personalChatFailed: return "Personal chat failed"
        case .recapFailed: return "Game recap failed"
        }
    }
}
