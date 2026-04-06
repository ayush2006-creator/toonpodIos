import Foundation

/// Persistent local storage for game progress (replaces localStorage from web)
class StorageService {
    static let shared = StorageService()

    private let defaults = UserDefaults.standard
    private let storageKey = "toontrivia_data"

    // MARK: - Storage Data

    struct StorageData: Codable {
        var completedSets: [String: [String]] = [:]
        var partialSets: [String: [String]] = [:]
        var totalWinnings: Int = 0
        var bestGame: Int = 0
    }

    func load() -> StorageData {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(StorageData.self, from: data) else {
            return StorageData()
        }
        return stored
    }

    func save(_ data: StorageData) {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Helpers

    func storageKey(level: Int, category: String) -> String {
        "\(category)_\(level)"
    }

    func getGamesCompleted(level: Int, category: String) -> Int {
        let data = load()
        let key = storageKey(level: level, category: category)
        return data.completedSets[key]?.count ?? 0
    }

    func getGamesPlayed(level: Int, category: String) -> Int {
        let data = load()
        let key = storageKey(level: level, category: category)
        return data.completedSets[key]?.count ?? 0
    }

    func isLevelFullyComplete(level: Int, category: String, totalGames: Int) -> Bool {
        getGamesCompleted(level: level, category: category) >= totalGames
    }

    func recordGamePlayed(level: Int, category: String, winnings: Int, setId: String?) {
        var data = load()
        let key = storageKey(level: level, category: category)

        if data.completedSets[key] == nil { data.completedSets[key] = [] }
        if let setId, !data.completedSets[key]!.contains(setId) {
            data.completedSets[key]!.append(setId)
        }

        // Remove from partial
        if let setId {
            data.partialSets[key]?.removeAll { $0 == setId }
        }

        data.totalWinnings += winnings
        if winnings > data.bestGame { data.bestGame = winnings }
        save(data)
    }

    func recordGameStarted(level: Int, category: String, setId: String?) {
        guard let setId else { return }
        var data = load()
        let key = storageKey(level: level, category: category)
        if data.completedSets[key]?.contains(setId) == true { return }
        if data.partialSets[key] == nil { data.partialSets[key] = [] }
        if !data.partialSets[key]!.contains(setId) {
            data.partialSets[key]!.append(setId)
        }
        save(data)
    }

    func getPlayedSetIds(level: Int, category: String) -> (completed: [String], partial: [String]) {
        let data = load()
        let key = storageKey(level: level, category: category)
        return (
            completed: data.completedSets[key] ?? [],
            partial: data.partialSets[key] ?? []
        )
    }
}
