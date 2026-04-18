import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @StateObject private var vm = HomeViewModel()
    @State private var showMenu = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // Streak badge
                    if vm.loginStreak > 0 {
                        Button {
                            vm.showStreakSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("\u{1F525}")
                                Text("\(vm.loginStreak)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(16)
                        }
                    }

                    Spacer()

                    if vm.isAuthenticated {
                        HStack(spacing: 12) {
                            Button {
                                vm.showSparksSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\u{26A1}")
                                    Text(formatCompact(vm.sparksBalance).replacingOccurrences(of: "$", with: ""))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.yellow)
                            }

                            Menu {
                                Button("Settings") { vm.showSettingsSheet = true }
                                Button("Feedback") { }
                                Button("Sign Out", role: .destructive) { vm.isAuthenticated = false }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(vm.userName.isEmpty ? "Player" : vm.userName)
                                        .foregroundColor(.white)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    } else {
                        Button("Sign In") {
                            vm.showAuthSheet = true
                        }
                        .foregroundColor(.purple.opacity(0.8))
                        .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Brand
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text("toon")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                        Text("TRIVIA")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    Text("The toon-hosted game show")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))

                    // Streak multiplier display
                    if vm.streakMultiplier > 1.0 {
                        HStack(spacing: 4) {
                            Text("\u{1F525}")
                            Text("\(String(format: "%.0f", (vm.streakMultiplier - 1.0) * 100))% score boost")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                Spacer().frame(height: 40)

                // Navigation Cards
                VStack(spacing: 16) {
                    // Single Player
                    NavigationLink(value: AppRoute.avatar) {
                        GameModeCard(
                            icon: "play.fill",
                            title: "Single Player",
                            subtitle: "15 questions per game",
                            isPrimary: true
                        )
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        gameVM.partyMode = false
                    })

                    // Party Mode
                    NavigationLink(value: AppRoute.partySetup) {
                        GameModeCard(
                            icon: "person.3.fill",
                            title: "Party Mode",
                            subtitle: "2-6 players · voice buzz-in",
                            isPrimary: false,
                            badge: "Must Play"
                        )
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        gameVM.partyMode = true
                    })

                    // Community Games
                    NavigationLink(value: AppRoute.community) {
                        GameModeCard(
                            icon: "globe",
                            title: "Community Games",
                            subtitle: "Play & create custom games",
                            isPrimary: false
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Bottom buttons
                HStack(spacing: 40) {
                    Button {
                        vm.showSparksSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                                .font(.title3)
                            Text("Shop")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }

                    Button {
                        vm.showRankingsSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.title3)
                            Text("Rankings")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $vm.showAuthSheet) {
            AuthSheet()
        }
        .sheet(isPresented: $vm.showRankingsSheet) {
            RankingsSheet()
        }
        .sheet(isPresented: $vm.showSparksSheet) {
            SparksSheet()
        }
        .sheet(isPresented: $vm.showStreakSheet) {
            StreakSheet(streak: vm.loginStreak, title: vm.streakTitle)
        }
    }
}

// MARK: - Streak Sheet

struct StreakSheet: View {
    let streak: Int
    let title: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("\u{1F525}")
                        .font(.system(size: 72))

                    Text("\(streak) Day Streak!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let title {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(20)
                    }

                    // Milestones
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(AppConstants.streakMilestones, id: \.0) { threshold, name in
                            HStack(spacing: 12) {
                                Image(systemName: streak >= threshold ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(streak >= threshold ? .green : .white.opacity(0.3))
                                Text("\(threshold) days")
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 60, alignment: .trailing)
                                Text(name)
                                    .foregroundColor(streak >= threshold ? .white : .white.opacity(0.4))
                                    .fontWeight(streak >= threshold ? .semibold : .regular)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                    Spacer()
                }
                .padding(.top, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

// MARK: - Game Mode Card

struct GameModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isPrimary ? Color.purple : Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isPrimary
                    ? LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .leading, endPoint: .trailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isPrimary ? 0.2 : 0.1), lineWidth: 1)
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
