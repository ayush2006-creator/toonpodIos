import SwiftUI

@main
struct TriviaApp: App {
    @StateObject private var gameVM = GameViewModel()
    @StateObject private var avatarVM = AvatarViewModel()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameVM)
                .environmentObject(avatarVM)
                .environmentObject(auth)
        }
    }
}
