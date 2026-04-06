import Foundation

enum AppRoute: Hashable {
    case home
    case avatar
    case category
    case levels
    case game
    case results
    case community
    case communityPlay(gameId: String)
}
