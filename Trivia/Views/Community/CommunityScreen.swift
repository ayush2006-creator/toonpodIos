import SwiftUI

struct CommunityScreen: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var gameVM: GameViewModel
    @State private var publicGames: [CommunityGame] = []
    @State private var isLoading = true
    @State private var shareCode = ""
    @State private var joiningCode = false
    @State private var shareCodeError: String?
    @State private var showCreateSheet = false
    @State private var sortBy: SortOption = .popular
    @State private var startingGame = false

    // Sheets presented by the sparks gate + auth gate
    @State private var showSparksSheet = false
    @State private var showAuthSheet = false
    @State private var pendingGame: CommunityGame?

    enum SortOption: String, CaseIterable {
        case popular = "Popular"
        case newest = "Newest"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Community Games")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Sparks balance pill (only when signed in)
                if auth.isAuthenticated {
                    Button {
                        showSparksSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("\u{26A1}")
                            Text("\(auth.sparksBalance) sparks")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(12)
                    }
                }

                // Share code input
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Enter share code", text: $shareCode)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)

                        Button {
                            joinByShareCode()
                        } label: {
                            Group {
                                if joiningCode {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Join").fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(shareCode.isEmpty ? Color.gray.opacity(0.3) : Color.purple)
                            .cornerRadius(10)
                        }
                        .disabled(shareCode.isEmpty || joiningCode)
                    }

                    if let shareCodeError {
                        Text(shareCodeError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                // Sort picker
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .onChange(of: sortBy) { _, _ in Task { await loadGames() } }

                // Games list
                if isLoading {
                    Spacer()
                    ProgressView().tint(.purple)
                    Spacer()
                } else if publicGames.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.3))
                        Text("No community games yet")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(publicGames) { game in
                                Button { startGame(game) } label: {
                                    CommunityGameCard(game: game)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Create button
                Button {
                    guard auth.isAuthenticated else {
                        showAuthSheet = true
                        return
                    }
                    showCreateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Game")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadGames() }
        .sheet(isPresented: $showSparksSheet) { SparksSheet() }
        .sheet(isPresented: $showAuthSheet) { AuthSheet() }
        .navigationDestination(isPresented: $navigateToGame) {
            GameScreen()
        }
    }

    // MARK: - Actions

    private func loadGames() async {
        isLoading = true
        do {
            publicGames = try await FirestoreService.shared.fetchPublicGames(sortByPopular: sortBy == .popular)
        } catch {
            publicGames = []
        }
        isLoading = false
    }

    private func joinByShareCode() {
        let code = shareCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        shareCodeError = nil
        joiningCode = true
        Task {
            do {
                if let game = try await FirestoreService.shared.fetchGame(byShareCode: code) {
                    joiningCode = false
                    startGame(game)
                } else {
                    shareCodeError = "No game with that code"
                    joiningCode = false
                }
            } catch {
                shareCodeError = "Couldn't look up that code"
                joiningCode = false
            }
        }
    }

    /// Entry point when a user taps a community game: enforce auth + sparks
    /// gating, mirroring CommunityPlayScreen.handleStart in the web client.
    private func startGame(_ game: CommunityGame) {
        guard auth.isAuthenticated else {
            pendingGame = game
            showAuthSheet = true
            return
        }
        if auth.sparksBalance < AppConstants.sparksPerGame {
            pendingGame = game
            showSparksSheet = true
            return
        }
        guard !startingGame else { return }
        startingGame = true
        Task {
            // List cards don't carry the embedded questions — fetch the full
            // game doc now, then hand off to GameViewModel.
            let loaded: CommunityGame?
            if !game.questions.isEmpty {
                loaded = game
            } else {
                loaded = try? await FirestoreService.shared.fetchCommunityGame(id: game.id)
            }
            startingGame = false
            guard let full = loaded, !full.questions.isEmpty else {
                shareCodeError = "Couldn't load questions for this game"
                return
            }
            gameVM.startCommunityGame(full)
            navigateToGame = true
        }
    }

    @State private var navigateToGame = false
}

// MARK: - Community Game Card

struct CommunityGameCard: View {
    let game: CommunityGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                    Text("\(game.playCount)")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.5))
            }

            if !game.description.isEmpty {
                Text(game.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }

            HStack {
                Text("by \(game.creatorName)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                // Rating
                if game.ratingCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", game.averageRating))
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                // Tags
                ForEach(game.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Sparks cost hint — mirrors web's cp-sparks-cost row
            HStack(spacing: 4) {
                Text("\u{26A1}")
                    .font(.caption2)
                Text("Up to \(AppConstants.sparksPerGame) sparks")
                    .font(.caption2)
                    .foregroundColor(.yellow.opacity(0.8))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
