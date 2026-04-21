import Foundation

// MARK: - FirestoreService
//
// Thin REST client for the subset of Firestore operations the iOS app needs:
//
//   • users/{uid}          — read + write sparks balance, profile, winnings
//   • communityGames       — list public + look-up by shareCode + fetch full game
//   • communityGamePlays   — record a play (increments playCount)
//   • scores               — save per-game results + read leaderboard
//
// We hit the Google REST endpoints directly (no Firebase SDK). Every
// authenticated write goes through the user's idToken so Firestore security
// rules still apply.

actor FirestoreService {
    static let shared = FirestoreService()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Question init uses its own decoder keys; nothing extra needed here.
        return d
    }()

    // MARK: - Users

    func createUserDoc(uid: String, displayName: String, initialSparks: Int, idToken: String) async throws {
        let url = URL(string: "\(FirebaseConfig.firestoreBase)/users/\(uid)")!
        let fields: [String: Any] = [
            "fields": [
                "userId":        ["stringValue": uid],
                "displayName":   ["stringValue": displayName],
                "sparks":        ["integerValue": "\(initialSparks)"],
                "totalWinnings": ["integerValue": "0"],
                "gamesPlayed":   ["integerValue": "0"],
            ]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)
        _ = try await session.data(for: req)
    }

    func fetchSparks(uid: String, idToken: String) async throws -> Int {
        let url = URL(string: "\(FirebaseConfig.firestoreBase)/users/\(uid)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return 0 }
        guard status == 200 else { throw URLError(.badServerResponse) }
        let doc = try decoder.decode(FirestoreDocument.self, from: data)
        return doc.fields?["sparks"]?.intValue ?? 0
    }

    func setSparks(uid: String, balance: Int, idToken: String) async throws {
        var components = URLComponents(string: "\(FirebaseConfig.firestoreBase)/users/\(uid)")!
        components.queryItems = [URLQueryItem(name: "updateMask.fieldPaths", value: "sparks")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": ["sparks": ["integerValue": "\(balance)"]]
        ])
        let (_, response) = try await session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Community games

    func fetchPublicGames(sortByPopular: Bool = true) async throws -> [CommunityGame] {
        let url = URL(string: "\(FirebaseConfig.firestoreBase):runQuery")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let orderField = sortByPopular ? "playCount" : "createdAt"
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "communityGames"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "isPublic"],
                        "op": "EQUAL",
                        "value": ["booleanValue": true],
                    ]
                ],
                "orderBy": [[
                    "field": ["fieldPath": orderField],
                    "direction": "DESCENDING",
                ]],
                "limit": 50,
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let rows = try decoder.decode([RunQueryRow].self, from: data)
        return rows.compactMap { $0.document?.toCommunityGame(includeQuestions: false) }
    }

    func fetchGame(byShareCode code: String) async throws -> CommunityGame? {
        let url = URL(string: "\(FirebaseConfig.firestoreBase):runQuery")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "communityGames"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "shareCode"],
                        "op": "EQUAL",
                        "value": ["stringValue": code.uppercased()],
                    ]
                ],
                "limit": 1,
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let rows = try decoder.decode([RunQueryRow].self, from: data)
        return rows.first?.document?.toCommunityGame(includeQuestions: true)
    }

    /// Fetch the full game document including the embedded questions list.
    func fetchCommunityGame(id: String) async throws -> CommunityGame? {
        let url = URL(string: "\(FirebaseConfig.firestoreBase)/communityGames/\(id)")!
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }
        let doc = try decoder.decode(FirestoreDocument.self, from: data)
        return doc.toCommunityGame(includeQuestions: true)
    }

    /// Mirrors recordCommunityPlay in web/services/community.ts. Bumps playCount
    /// and appends a play record. Requires an authenticated idToken.
    func recordCommunityPlay(gameId: String, uid: String, winnings: Int, correct: Int, idToken: String) async throws {
        // 1. Add play record.
        let playsURL = URL(string: "\(FirebaseConfig.firestoreBase)/communityGamePlays")!
        var playReq = URLRequest(url: playsURL)
        playReq.httpMethod = "POST"
        playReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        playReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        playReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": [
                "gameId":    ["stringValue": gameId],
                "userId":    ["stringValue": uid],
                "winnings":  ["integerValue": "\(winnings)"],
                "correct":   ["integerValue": "\(correct)"],
                "rating":    ["integerValue": "0"],
                "playedAt":  ["timestampValue": timestamp],
            ]
        ])
        _ = try await session.data(for: playReq)

        // 2. Increment playCount via the `:commit` endpoint with a transform.
        let commitURL = URL(string: "\(FirebaseConfig.firestoreBase):commit")!
        var commitReq = URLRequest(url: commitURL)
        commitReq.httpMethod = "POST"
        commitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        commitReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let docName = "projects/\(FirebaseConfig.projectId)/databases/(default)/documents/communityGames/\(gameId)"
        commitReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "writes": [[
                "transform": [
                    "document": docName,
                    "fieldTransforms": [[
                        "fieldPath": "playCount",
                        "increment": ["integerValue": "1"],
                    ]]
                ]
            ]]
        ])
        _ = try await session.data(for: commitReq)
    }

    // MARK: - Scores & leaderboard

    /// Save a score and update the user's totals. Mirrors web saveScore in AuthContext.
    func saveScore(uid: String, displayName: String, data: ScoreData, questionSetId: String?, category: String?, idToken: String) async throws {
        // 1. Add scores entry.
        let scoresURL = URL(string: "\(FirebaseConfig.firestoreBase)/scores")!
        var scoreReq = URLRequest(url: scoresURL)
        scoreReq.httpMethod = "POST"
        scoreReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        scoreReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        var fields: [String: Any] = [
            "userId":        ["stringValue": uid],
            "displayName":   ["stringValue": displayName],
            "level":         ["integerValue": "\(data.level)"],
            "winnings":      ["integerValue": "\(data.winnings)"],
            "correct":       ["integerValue": "\(data.correct)"],
            "totalQs":       ["integerValue": "\(data.totalQs)"],
            "maxStreak":     ["integerValue": "\(data.maxStreak)"],
            "gameMode":      ["stringValue": data.gameMode],
            "playedAt":      ["timestampValue": ISO8601DateFormatter().string(from: Date())],
        ]
        if let setId = questionSetId {
            fields["questionSetId"] = ["stringValue": setId]
        }
        if let cat = category {
            fields["category"] = ["stringValue": cat]
        }
        scoreReq.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])
        _ = try await session.data(for: scoreReq)

        // 2. Commit user totals increment atomically.
        let commitURL = URL(string: "\(FirebaseConfig.firestoreBase):commit")!
        var commitReq = URLRequest(url: commitURL)
        commitReq.httpMethod = "POST"
        commitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        commitReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let docName = "projects/\(FirebaseConfig.projectId)/databases/(default)/documents/users/\(uid)"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        commitReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "writes": [
                // Ensure displayName + userId exist (upsert) — merges with existing.
                [
                    "update": [
                        "name": docName,
                        "fields": [
                            "userId":      ["stringValue": uid],
                            "displayName": ["stringValue": displayName],
                            "lastUpdated": ["timestampValue": timestamp],
                        ]
                    ],
                    "updateMask": ["fieldPaths": ["userId", "displayName", "lastUpdated"]],
                ],
                [
                    "transform": [
                        "document": docName,
                        "fieldTransforms": [
                            [
                                "fieldPath": "totalWinnings",
                                "increment": ["integerValue": "\(data.winnings)"],
                            ],
                            [
                                "fieldPath": "gamesPlayed",
                                "increment": ["integerValue": "1"],
                            ],
                        ]
                    ]
                ]
            ]
        ])
        _ = try await session.data(for: commitReq)
    }

    /// Top N players by totalWinnings (all-time).
    func fetchAllTimeRankings(limit: Int = 50) async throws -> [RankingEntry] {
        let url = URL(string: "\(FirebaseConfig.firestoreBase):runQuery")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "users"]],
                "orderBy": [[
                    "field": ["fieldPath": "totalWinnings"],
                    "direction": "DESCENDING",
                ]],
                "limit": limit,
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let rows = try decoder.decode([RunQueryRow].self, from: data)
        return rows.compactMap { $0.document?.toRankingEntry() }
    }

    /// Aggregate winnings per user over the current week (Monday → now).
    /// Mirrors web loadWeeklyRankings.
    func fetchWeeklyRankings(limit: Int = 50) async throws -> [RankingEntry] {
        let url = URL(string: "\(FirebaseConfig.firestoreBase):runQuery")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let weekStart = startOfUTCWeek()
        let timestamp = ISO8601DateFormatter().string(from: weekStart)
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "scores"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "playedAt"],
                        "op": "GREATER_THAN_OR_EQUAL",
                        "value": ["timestampValue": timestamp],
                    ]
                ],
                "orderBy": [[
                    "field": ["fieldPath": "playedAt"],
                    "direction": "DESCENDING",
                ]],
                "limit": 500,
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let rows = try decoder.decode([RunQueryRow].self, from: data)

        // Aggregate winnings per user
        var totals: [String: (entry: RankingEntry, runningTotal: Int, games: Int)] = [:]
        for row in rows {
            guard let fields = row.document?.fields else { continue }
            let uid = fields["userId"]?.stringValue ?? ""
            guard !uid.isEmpty else { continue }
            let win = fields["winnings"]?.intValue ?? 0
            let name = fields["displayName"]?.stringValue ?? "Player"
            if var cur = totals[uid] {
                cur.runningTotal += win
                cur.games += 1
                totals[uid] = cur
            } else {
                let entry = RankingEntry(userId: uid, displayName: name, totalWinnings: 0, gamesPlayed: 0, sparks: nil)
                totals[uid] = (entry, win, 1)
            }
        }
        return totals.values
            .map { RankingEntry(userId: $0.entry.userId,
                                displayName: $0.entry.displayName,
                                totalWinnings: $0.runningTotal,
                                gamesPlayed: $0.games,
                                sparks: nil) }
            .sorted { $0.totalWinnings > $1.totalWinnings }
            .prefix(limit)
            .map { $0 }
    }

    private func startOfUTCWeek() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        cal.firstWeekday = 2 // Monday
        let now = Date()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: comps) ?? now
    }
}

// MARK: - Firestore REST shapes

private struct RunQueryRow: Decodable {
    let document: FirestoreDocument?
}

private struct FirestoreDocument: Decodable {
    let name: String?
    let fields: [String: FirestoreValue]?

    var id: String {
        (name ?? "").components(separatedBy: "/").last ?? ""
    }

    func toCommunityGame(includeQuestions: Bool) -> CommunityGame? {
        guard let f = fields else { return nil }
        let questions: [Question]
        if includeQuestions, let arr = f["questions"]?.arrayValue {
            questions = arr.compactMap { $0.decodeQuestion() }
        } else {
            questions = []
        }
        return CommunityGame(
            id: id,
            title:        f["title"]?.stringValue ?? "",
            description:  f["description"]?.stringValue ?? "",
            tags:         f["tags"]?.arrayValue?.compactMap { $0.stringValue } ?? [],
            creatorId:    f["creatorId"]?.stringValue ?? "",
            creatorName:  f["creatorName"]?.stringValue ?? "Player",
            isPublic:     f["isPublic"]?.booleanValue ?? false,
            shareCode:    f["shareCode"]?.stringValue ?? "",
            questions:    questions,
            playCount:    f["playCount"]?.intValue ?? 0,
            totalRating:  f["totalRating"]?.intValue ?? 0,
            ratingCount:  f["ratingCount"]?.intValue ?? 0,
            createdAt:    f["createdAt"]?.timestampValue ?? Date(),
            updatedAt:    f["updatedAt"]?.timestampValue ?? Date()
        )
    }

    func toRankingEntry() -> RankingEntry? {
        guard let f = fields else { return nil }
        let uid = f["userId"]?.stringValue ?? id
        return RankingEntry(
            userId: uid,
            displayName:   f["displayName"]?.stringValue ?? "Player",
            totalWinnings: f["totalWinnings"]?.intValue ?? 0,
            gamesPlayed:   f["gamesPlayed"]?.intValue ?? 0,
            sparks:        f["sparks"]?.intValue
        )
    }
}

// MARK: - FirestoreValue
//
// A single Firestore REST value is a one-key dict tagged by type. We eagerly
// decode all tag variants (most come back nil).

private struct FirestoreValue: Decodable {
    struct ArrayContainer: Decodable { let values: [FirestoreValue]? }
    struct MapContainer:   Decodable { let fields: [String: FirestoreValue]? }

    let stringValue:       String?
    let integerValue:      String?
    let doubleValue:       Double?
    let booleanValue:      Bool?
    let timestampValueRaw: String?
    let nullValue:         String?
    let arrayContainer:    ArrayContainer?
    let mapContainer:      MapContainer?

    enum CodingKeys: String, CodingKey {
        case stringValue, integerValue, doubleValue, booleanValue, nullValue
        case timestampValueRaw = "timestampValue"
        case arrayContainer    = "arrayValue"
        case mapContainer      = "mapValue"
    }

    var intValue: Int? {
        if let s = integerValue, let i = Int(s) { return i }
        if let d = doubleValue { return Int(d) }
        return nil
    }

    var timestampValue: Date? {
        guard let s = timestampValueRaw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }

    var arrayValue: [FirestoreValue]? { arrayContainer?.values }
    var mapValue:   [String: FirestoreValue]? { mapContainer?.fields }

    /// Lower this Firestore value into plain JSON-representable Swift values.
    /// Used to re-hydrate complex types (Question) via JSONDecoder.
    var jsonValue: Any {
        if let s = stringValue        { return s }
        if let i = intValue           { return i }
        if let d = doubleValue        { return d }
        if let b = booleanValue       { return b }
        if let t = timestampValueRaw  { return t }
        if let arr = arrayValue       { return arr.map(\.jsonValue) }
        if let map = mapValue {
            var out: [String: Any] = [:]
            for (k, v) in map { out[k] = v.jsonValue }
            return out
        }
        return NSNull()
    }

    /// Decode a Question from this Firestore map value by round-tripping
    /// through JSONSerialization → JSONDecoder so Question's existing
    /// custom init(from:) runs unchanged.
    func decodeQuestion() -> Question? {
        guard let map = mapValue else { return nil }
        var json: [String: Any] = [:]
        for (k, v) in map { json[k] = v.jsonValue }
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? JSONDecoder().decode(Question.self, from: data)
    }
}
