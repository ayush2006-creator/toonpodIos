import SwiftUI

struct LevelsScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @StateObject private var vm = LevelsViewModel()

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Select Level")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Sparks banner
                HStack(spacing: 8) {
                    Text("\u{26A1}")
                    Text("\(AppConstants.initialSparks)")
                        .fontWeight(.bold)
                    Text("sparks")
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(AppConstants.sparksPerGame) per game")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.levels) { level in
                            NavigationLink(value: AppRoute.game) {
                                LevelCard(level: level)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                gameVM.currentLevel = level.level
                            })
                            .disabled(!level.unlocked || level.allComplete)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            vm.loadLevels(category: gameVM.selectedCategory)
        }
    }
}

// MARK: - Level Card

struct LevelCard: View {
    let level: LevelsViewModel.LevelInfo

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(cardColor)
                    .frame(width: 48, height: 48)

                if level.allComplete {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if !level.unlocked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("\(level.level)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            Text(level.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(level.completed)/\(level.totalGames)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(level.unlocked ? 0.08 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(level.allComplete ? 0.3 : 0.1), lineWidth: 1)
        )
        .opacity(level.unlocked ? 1 : 0.5)
    }

    private var progress: CGFloat {
        level.totalGames > 0 ? CGFloat(level.completed) / CGFloat(level.totalGames) : 0
    }

    private var cardColor: Color {
        if level.allComplete { return .green }
        if !level.unlocked { return .gray }
        return .purple
    }

    private var progressColor: Color {
        level.allComplete ? .green : .purple
    }
}
