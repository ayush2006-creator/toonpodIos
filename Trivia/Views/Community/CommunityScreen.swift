import SwiftUI

struct CommunityScreen: View {
    @State private var publicGames: [CommunityGame] = []
    @State private var isLoading = true
    @State private var shareCode = ""
    @State private var showCreateSheet = false
    @State private var sortBy: SortOption = .popular

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

                // Share code input
                HStack(spacing: 12) {
                    TextField("Enter share code", text: $shareCode)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .textInputAutocapitalization(.characters)

                    Button {
                        // Join by share code
                    } label: {
                        Text("Join")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(shareCode.isEmpty ? Color.gray.opacity(0.3) : Color.purple)
                            .cornerRadius(10)
                    }
                    .disabled(shareCode.isEmpty)
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

                // Games list
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.purple)
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
                                CommunityGameCard(game: game)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Create button
                Button {
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
        .onAppear { isLoading = false }
    }
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
