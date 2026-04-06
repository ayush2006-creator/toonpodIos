import Foundation

@MainActor
class LevelsViewModel: ObservableObject {
    @Published var levels: [LevelInfo] = []

    struct LevelInfo: Identifiable {
        let id: Int
        let level: Int
        let name: String
        let completed: Int
        let totalGames: Int
        let unlocked: Bool
        let allComplete: Bool
    }

    func loadLevels(category: String) {
        let totalGames = AppConstants.gamesPerLevel[category] ?? 5
        let gamesToUnlock = AppConstants.getGamesToUnlock(category: category)

        levels = (1...10).map { level in
            let completed = StorageService.shared.getGamesCompleted(level: level, category: category)
            let unlocked = level == 1 || StorageService.shared.getGamesPlayed(level: level - 1, category: category) >= gamesToUnlock
            let allComplete = completed >= totalGames

            return LevelInfo(
                id: level,
                level: level,
                name: AppConstants.levelNames[level - 1],
                completed: completed,
                totalGames: totalGames,
                unlocked: unlocked,
                allComplete: allComplete
            )
        }
    }
}
