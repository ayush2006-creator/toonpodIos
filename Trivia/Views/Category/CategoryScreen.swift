import SwiftUI

struct CategoryScreen: View {
    @EnvironmentObject var gameVM: GameViewModel

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

            VStack(spacing: 24) {
                Text("Choose Category")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Featured: General Trivia
                let general = triviaCategories[0]
                NavigationLink(value: AppRoute.levels) {
                    CategoryCard(category: general, isFeatured: true)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    gameVM.selectedCategory = general.slug
                })
                .padding(.horizontal, 24)

                // Other categories grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(triviaCategories.dropFirst()) { cat in
                        NavigationLink(value: AppRoute.levels) {
                            CategoryCard(category: cat, isFeatured: false)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            gameVM.selectedCategory = cat.slug
                        })
                        .disabled(!cat.available)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: TriviaCategory
    let isFeatured: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(category.emoji)
                .font(isFeatured ? .system(size: 48) : .system(size: 32))

            Text(category.name)
                .font(isFeatured ? .headline : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(category.desc)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            if !category.available {
                Text("Coming Soon")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isFeatured ? 24 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFeatured
                    ? LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isFeatured ? 0.2 : 0.1), lineWidth: 1)
        )
        .opacity(category.available ? 1 : 0.5)
    }
}
