import SwiftUI

struct AvatarScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @EnvironmentObject var avatarVM: AvatarViewModel
    @State private var selectedIndex: Int = 0

    private var availableAvatars: [AvatarDefinition] {
        appAvatars.filter { $0.available != .comingSoon }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Choose Your Host")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // 3D Avatar Preview
                AvatarModelView(
                    modelName: availableAvatars[selectedIndex].modelFileName,
                    allowsRotation: true,
                    autoRotate: true,
                    showPlatform: true
                )
                .frame(height: 300)
                .padding(.horizontal, 24)
                .id(selectedIndex) // force refresh on selection change

                // Avatar name & personality
                VStack(spacing: 6) {
                    Text(availableAvatars[selectedIndex].name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(availableAvatars[selectedIndex].personality)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Avatar selection cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(appAvatars.enumerated()), id: \.element.id) { index, avatar in
                            AvatarCard(
                                avatar: avatar,
                                isSelected: selectedIndex == index,
                                onSelect: {
                                    if avatar.available != .comingSoon {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedIndex = index
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Text(gameVM.partyMode ? "Party Mode - 2-5 Players" : "Single Player")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                // Continue button
                NavigationLink(value: AppRoute.category) {
                    Text("Choose Category")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let avatar = availableAvatars[selectedIndex]
                    gameVM.selectedAvatarId = avatar.id
                    avatarVM.selectAvatar(avatar)
                })
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Avatar Selection Card

struct AvatarCard: View {
    let avatar: AvatarDefinition
    let isSelected: Bool
    let onSelect: () -> Void

    private var isLocked: Bool { avatar.available == .comingSoon }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Avatar icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.purple : Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text(avatarEmoji)
                            .font(.system(size: 28))
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )

                Text(avatar.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                if isLocked {
                    Text("Coming Soon")
                        .font(.system(size: 9))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .opacity(isLocked ? 0.5 : 1)
        }
        .disabled(isLocked)
    }

    private var avatarEmoji: String {
        switch avatar.id {
        case "trixie": return "👩"
        case "nova": return "🌟"
        case "rex": return "👨‍💼"
        case "soldier": return "🪖"
        default: return "🧙"
        }
    }
}
