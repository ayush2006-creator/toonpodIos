import SwiftUI

@main
struct TriviaApp: App {
    @StateObject private var gameVM = GameViewModel()
    @StateObject private var avatarVM = AvatarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameVM)
                .environmentObject(avatarVM)
        }
    }
}
