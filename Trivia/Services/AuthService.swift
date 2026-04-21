import Foundation
import Combine

// MARK: - AuthUser

struct AuthUser: Equatable {
    var uid: String
    var email: String
    var displayName: String
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case emailInUse
    case weakPassword
    case networkError
    case notAuthenticated
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:      return "Invalid email address"
        case .wrongPassword:     return "Incorrect password"
        case .userNotFound:      return "No account with that email"
        case .emailInUse:        return "An account already exists with that email"
        case .weakPassword:      return "Password must be at least 6 characters"
        case .networkError:      return "Network error — check your connection"
        case .notAuthenticated:  return "You must be signed in"
        case .server(let msg):   return msg
        }
    }

    /// Map Firebase REST error codes to our typed errors.
    static func from(_ code: String) -> AuthError {
        switch code {
        case "INVALID_EMAIL":        return .invalidEmail
        case "INVALID_PASSWORD",
             "INVALID_LOGIN_CREDENTIALS": return .wrongPassword
        case "EMAIL_NOT_FOUND":      return .userNotFound
        case "EMAIL_EXISTS":         return .emailInUse
        case "WEAK_PASSWORD":        return .weakPassword
        default:                     return .server(code.replacingOccurrences(of: "_", with: " ").capitalized)
        }
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: ObservableObject {

    // MARK: Published state

    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var sparksBalance: Int = 0
    @Published private(set) var isRestoringSession: Bool = true

    var isAuthenticated: Bool { currentUser != nil }

    // MARK: Token state (in-memory idToken, persisted refresh token)

    private var idToken: String?
    private var idTokenExpiry: Date = .distantPast

    private enum KC {
        static let refreshToken = "refreshToken"
        static let uid          = "uid"
        static let email        = "email"
        static let displayName  = "displayName"
    }

    // MARK: - Init

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Public API

    /// Sign up with email/password, then create the Firestore user doc with
    /// starter sparks. Returns the new user.
    @discardableResult
    func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        let resp: SignInResponse = try await postIDT(
            path: "accounts:signUp",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
        applyTokens(idToken: resp.idToken, refreshToken: resp.refreshToken, expiresInSeconds: resp.expiresIn)

        let name = displayName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            _ = try? await updateProfile(displayName: name)
        }

        let user = AuthUser(uid: resp.localId, email: email, displayName: name)
        persistUser(user)
        currentUser = user

        // Create Firestore doc with initial sparks.
        try? await FirestoreService.shared.createUserDoc(
            uid: user.uid,
            displayName: name.isEmpty ? (email.components(separatedBy: "@").first ?? "Player") : name,
            initialSparks: AppConstants.initialSparks,
            idToken: resp.idToken
        )
        sparksBalance = AppConstants.initialSparks
        return user
    }

    /// Sign in with email/password. Loads user doc + sparks on success.
    @discardableResult
    func signIn(email: String, password: String) async throws -> AuthUser {
        let resp: SignInResponse = try await postIDT(
            path: "accounts:signInWithPassword",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
        applyTokens(idToken: resp.idToken, refreshToken: resp.refreshToken, expiresInSeconds: resp.expiresIn)

        let name = resp.displayName ?? ""
        let user = AuthUser(uid: resp.localId, email: email, displayName: name)
        persistUser(user)
        currentUser = user

        await refreshSparks()
        return user
    }

    /// Send a password-reset email via Firebase.
    func sendPasswordReset(email: String) async throws {
        let body: [String: Any] = ["requestType": "PASSWORD_RESET", "email": email]
        let _: ResetResponse = try await postIDT(path: "accounts:sendOobCode", body: body)
    }

    /// Sign out locally — clears Keychain + state. No server call needed.
    func signOut() {
        KeychainHelper.delete(KC.refreshToken)
        KeychainHelper.delete(KC.uid)
        KeychainHelper.delete(KC.email)
        KeychainHelper.delete(KC.displayName)
        idToken = nil
        idTokenExpiry = .distantPast
        currentUser = nil
        sparksBalance = 0
    }

    /// Update the user's displayName in Firebase Auth profile.
    func updateProfile(displayName: String) async throws {
        let tok = try await validToken()
        let _: EmptyResponse = try await postIDT(
            path: "accounts:update",
            body: ["idToken": tok, "displayName": displayName, "returnSecureToken": false]
        )
        if var user = currentUser {
            user.displayName = displayName
            currentUser = user
            KeychainHelper.set(displayName, for: KC.displayName)
        }
    }

    /// Refresh sparks balance from Firestore.
    func refreshSparks() async {
        guard let uid = currentUser?.uid,
              let tok = try? await validToken() else { return }
        if let bal = try? await FirestoreService.shared.fetchSparks(uid: uid, idToken: tok) {
            sparksBalance = bal
        }
    }

    /// Credit the user's sparks balance in Firestore (used after a completed
    /// purchase). Also updates the local balance.
    func addSparks(_ amount: Int) async {
        guard amount > 0, let uid = currentUser?.uid,
              let tok = try? await validToken() else { return }
        let newBalance = sparksBalance + amount
        if (try? await FirestoreService.shared.setSparks(uid: uid, balance: newBalance, idToken: tok)) != nil {
            sparksBalance = newBalance
        }
    }

    /// Deduct sparks locally + in Firestore. Used at game start.
    func deductSparks(_ amount: Int) async {
        guard amount > 0, let uid = currentUser?.uid,
              let tok = try? await validToken() else { return }
        let newBalance = max(0, sparksBalance - amount)
        if (try? await FirestoreService.shared.setSparks(uid: uid, balance: newBalance, idToken: tok)) != nil {
            sparksBalance = newBalance
        }
    }

    /// Persist a game score + update user totals so it surfaces on the
    /// leaderboard. Silently no-ops when the user isn't signed in.
    func saveScore(data: ScoreData, questionSetId: String?, category: String?) async {
        guard let user = currentUser,
              let tok = try? await validToken() else { return }
        let name = user.displayName.isEmpty
            ? (user.email.components(separatedBy: "@").first ?? "Player")
            : user.displayName
        try? await FirestoreService.shared.saveScore(
            uid: user.uid,
            displayName: name,
            data: data,
            questionSetId: questionSetId,
            category: category,
            idToken: tok
        )
    }

    /// Bump playCount on a community game and write a play record.
    func recordCommunityPlay(gameId: String, winnings: Int, correct: Int) async {
        guard let uid = currentUser?.uid,
              let tok = try? await validToken() else { return }
        try? await FirestoreService.shared.recordCommunityPlay(
            gameId: gameId, uid: uid, winnings: winnings, correct: correct, idToken: tok
        )
    }

    /// A valid idToken, refreshed on demand. Throws `notAuthenticated` if no session.
    func validToken() async throws -> String {
        if let tok = idToken, Date() < idTokenExpiry.addingTimeInterval(-30) {
            return tok
        }
        guard let refresh = KeychainHelper.get(KC.refreshToken) else {
            throw AuthError.notAuthenticated
        }
        return try await refreshIdToken(using: refresh)
    }

    // MARK: - Session restore

    private func restoreSession() async {
        defer { isRestoringSession = false }
        guard let refresh = KeychainHelper.get(KC.refreshToken),
              let uid = KeychainHelper.get(KC.uid) else { return }
        do {
            _ = try await refreshIdToken(using: refresh)
            let email = KeychainHelper.get(KC.email) ?? ""
            let name  = KeychainHelper.get(KC.displayName) ?? ""
            currentUser = AuthUser(uid: uid, email: email, displayName: name)
            await refreshSparks()
        } catch {
            // Refresh token rejected — clear and remain signed-out.
            signOut()
        }
    }

    // MARK: - Token refresh

    private func refreshIdToken(using refresh: String) async throws -> String {
        var request = URLRequest(url: URL(string: "\(FirebaseConfig.secureTokenURL)/token?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.notAuthenticated
        }
        let parsed = try JSONDecoder().decode(RefreshResponse.self, from: data)
        applyTokens(idToken: parsed.id_token,
                    refreshToken: parsed.refresh_token,
                    expiresInSeconds: parsed.expires_in)
        return parsed.id_token
    }

    // MARK: - Helpers

    private func applyTokens(idToken: String, refreshToken: String, expiresInSeconds: String) {
        self.idToken = idToken
        let secs = TimeInterval(expiresInSeconds) ?? 3600
        self.idTokenExpiry = Date().addingTimeInterval(secs)
        KeychainHelper.set(refreshToken, for: KC.refreshToken)
    }

    private func persistUser(_ user: AuthUser) {
        KeychainHelper.set(user.uid,         for: KC.uid)
        KeychainHelper.set(user.email,       for: KC.email)
        KeychainHelper.set(user.displayName, for: KC.displayName)
    }

    /// POST to Identity Toolkit and decode `T`. Throws `AuthError` on non-200.
    private func postIDT<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: "\(FirebaseConfig.identityToolkitURL)/\(path)?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            return try JSONDecoder().decode(T.self, from: data)
        }
        // Parse the Firebase error payload: { "error": { "message": "CODE" } }
        if let err = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            let code = err.error.message.components(separatedBy: " ").first ?? err.error.message
            throw AuthError.from(code)
        }
        throw AuthError.server("Request failed (\(status))")
    }

    // MARK: - DTOs

    private struct SignInResponse: Decodable {
        let localId: String
        let email: String?
        let displayName: String?
        let idToken: String
        let refreshToken: String
        let expiresIn: String
    }
    private struct RefreshResponse: Decodable {
        let id_token: String
        let refresh_token: String
        let expires_in: String
    }
    private struct ResetResponse: Decodable { let email: String? }
    private struct EmptyResponse: Decodable {}
    private struct ErrorEnvelope: Decodable {
        struct Inner: Decodable { let message: String }
        let error: Inner
    }
}
