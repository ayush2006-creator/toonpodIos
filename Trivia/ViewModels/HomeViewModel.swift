import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var loginStreak: Int = 0
    @Published var showAuthSheet = false
    @Published var showSettingsSheet = false
    @Published var showRankingsSheet = false
    @Published var showSparksSheet = false
    @Published var showStreakSheet = false

    var streakTitle: String? {
        for (threshold, title) in AppConstants.streakMilestones.reversed() {
            if loginStreak >= threshold { return title }
        }
        return nil
    }

    var streakMultiplier: Double {
        for (threshold, multiplier) in AppConstants.streakMultipliers.reversed() {
            if loginStreak >= threshold { return multiplier }
        }
        return 1.0
    }
}
