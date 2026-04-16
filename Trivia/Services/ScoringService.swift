import Foundation

enum ScoringService {
    static func calcSpeedBonus(prize: Int, elapsed: Double) -> Int {
        if elapsed < 2 { return Int(round(Double(prize) * 0.25)) }
        if elapsed < 4 { return Int(round(Double(prize) * 0.15)) }
        if elapsed < 6 { return Int(round(Double(prize) * 0.05)) }
        return 0
    }

    static func calcStreakBonus(prize: Int, streak: Int) -> Int {
        if streak >= 7 { return Int(round(Double(prize) * 0.5)) }
        if streak >= 5 { return Int(round(Double(prize) * 0.25)) }
        if streak >= 3 { return Int(round(Double(prize) * 0.1)) }
        return 0
    }

    /// Apply the daily login streak multiplier to a base prize. Returns the bonus amount (0 if multiplier is 1x).
    static func calcLoginStreakBonus(prize: Int, multiplier: Double) -> Int {
        guard multiplier > 1.0 else { return 0 }
        return Int(round(Double(prize) * (multiplier - 1.0)))
    }
}
