import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @StateObject private var partyVM = PartyViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeScreen()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .home:
                        HomeScreen()
                    case .avatar:
                        AvatarScreen()
                    case .category:
                        CategoryScreen()
                    case .levels:
                        LevelsScreen()
                    case .game:
                        GameScreen()
                    case .results:
                        ResultsScreen()
                    case .community:
                        CommunityScreen()
                    case .communityPlay:
                        GameScreen()
                    case .partySetup:
                        PartySetupScreen()
                            .environmentObject(partyVM)
                    case .partyGame:
                        PartyGameScreen()
                            .environmentObject(partyVM)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onChange(of: gameVM.gameAborted) {
            if gameVM.gameAborted {
                navigationPath = NavigationPath()
            }
        }
        .onChange(of: gameVM.gameComplete) {
            if gameVM.gameComplete {
                navigationPath.append(AppRoute.results)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameViewModel())
}
