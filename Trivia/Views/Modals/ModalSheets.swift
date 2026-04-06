import SwiftUI

// MARK: - Auth Sheet

struct AuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 24) {
                    // Logo
                    HStack(spacing: 0) {
                        Text("toon")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.white)
                        Text("TRIVIA")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                    }

                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)

                        SecureField("Password", text: $password)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)

                        Button {
                            // Firebase auth would go here
                            dismiss()
                        } label: {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        isSignUp.toggle()
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }

                    Spacer()
                }
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Rankings Sheet

struct RankingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rankings: [RankingEntry] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                if rankings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow.opacity(0.5))
                        Text("No rankings yet")
                            .foregroundColor(.white.opacity(0.5))
                        Text("Play some games to see the leaderboard!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(rankings.enumerated()), id: \.element.userId) { index, entry in
                                HStack(spacing: 12) {
                                    Text("#\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(index < 3 ? .yellow : .white.opacity(0.5))
                                        .frame(width: 36)

                                    Text(entry.displayName)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Text(formatMoney(entry.totalWinnings))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rankings")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

// MARK: - Sparks Sheet

struct SparksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("\u{26A1}")
                        .font(.system(size: 64))

                    Text("Sparks")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Sparks are used to play games. Each game costs \(AppConstants.sparksPerGame) sparks.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        SparkPackButton(name: "Starter Pack", sparks: 1000, price: "$0.99")
                        SparkPackButton(name: "Value Pack", sparks: 5000, price: "$3.99")
                        SparkPackButton(name: "Pro Pack", sparks: 15000, price: "$9.99")
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationTitle("Shop")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

struct SparkPackButton: View {
    let name: String
    let sparks: Int
    let price: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(sparks.formatted()) sparks")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            Spacer()

            Button {
                // Stripe checkout would go here
            } label: {
                Text(price)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}
