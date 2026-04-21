import SwiftUI
#if os(iOS)
import SafariServices
#endif

// MARK: - Auth Sheet

struct AuthSheet: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        !isSubmitting &&
        email.contains("@") &&
        password.count >= 6 &&
        (!isSignUp || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 20) {
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
                    .padding(.top, 20)

                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(spacing: 12) {
                        if isSignUp {
                            TextField("Display name", text: $displayName)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .textInputAutocapitalization(.words)
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        SecureField("Password (6+ chars)", text: $password)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .textContentType(isSignUp ? .newPassword : .password)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let infoMessage {
                            Text(infoMessage)
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            HStack {
                                if isSubmitting { ProgressView().tint(.white) }
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? Color.purple : Color.purple.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .disabled(!canSubmit)

                        if !isSignUp {
                            Button("Forgot password?") { resetPassword() }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        withAnimation { isSignUp.toggle() }
                        errorMessage = nil
                        infoMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        Task {
            do {
                if isSignUp {
                    _ = try await auth.signUp(email: email, password: password, displayName: displayName)
                } else {
                    _ = try await auth.signIn(email: email, password: password)
                }
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = (error as? AuthError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func resetPassword() {
        guard email.contains("@") else {
            errorMessage = "Enter your email first"
            return
        }
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        Task {
            do {
                try await auth.sendPasswordReset(email: email)
                infoMessage = "Password reset email sent"
            } catch {
                errorMessage = (error as? AuthError)?.errorDescription
                    ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Rankings Sheet

struct RankingsSheet: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .allTime
    @State private var allTime: [RankingEntry] = []
    @State private var weekly:  [RankingEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum Tab: String, CaseIterable {
        case allTime = "All-Time"
        case weekly  = "This Week"
    }

    private var displayed: [RankingEntry] { tab == .allTime ? allTime : weekly }
    private var myUid: String? { auth.currentUser?.uid }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 12) {
                    Picker("Range", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.purple)
                        Spacer()
                    } else if displayed.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.largeTitle)
                                .foregroundColor(.yellow.opacity(0.5))
                            Text(errorMessage ?? "No rankings yet")
                                .foregroundColor(.white.opacity(0.5))
                            Text("Play some games to see the leaderboard!")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(Array(displayed.enumerated()), id: \.element.userId) { index, entry in
                                    rankRow(entry: entry, rank: index + 1, isMe: entry.userId == myUid)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
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
            .task { await loadRankings() }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func rankRow(entry: RankingEntry, rank: Int, isMe: Bool) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? .yellow : .white.opacity(0.5))
                .frame(width: 42, alignment: .leading)

            Text(entry.displayName.isEmpty ? "Player" : entry.displayName)
                .foregroundColor(isMe ? .white : .white.opacity(0.85))
                .fontWeight(isMe ? .bold : .regular)

            if isMe {
                Text("you")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.25))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            Spacer()

            Text(formatMoney(entry.totalWinnings))
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? Color.purple.opacity(0.15) : Color.white.opacity(0.04))
        .cornerRadius(10)
    }

    // MARK: - Loading

    private func loadRankings() async {
        isLoading = true
        errorMessage = nil
        async let allTimeTask = (try? await FirestoreService.shared.fetchAllTimeRankings()) ?? []
        async let weeklyTask  = (try? await FirestoreService.shared.fetchWeeklyRankings())  ?? []
        let (a, w) = await (allTimeTask, weeklyTask)
        allTime = a
        weekly  = w
        isLoading = false
    }
}

// MARK: - Sparks Sheet

struct SparksSheet: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var checkoutURL: URL?
    @State private var loadingPack: String?
    @State private var errorMessage: String?

    /// Matches the server's SPARK_PACKS definitions (server.js:364).
    private struct Pack { let id, name, amount, price: String }
    private let packs: [Pack] = [
        .init(id: "2k",  name: "Mini Pack",    amount: "2,000",  price: "$1.99"),
        .init(id: "5k",  name: "Starter Pack", amount: "5,000",  price: "$4.99"),
        .init(id: "11k", name: "Power Pack",   amount: "11,000", price: "$9.99"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d001a").ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("\u{26A1}")
                        .font(.system(size: 64))

                    Text("Get Sparks")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Use sparks to play games. Each game costs up to \(AppConstants.sparksPerGame) sparks.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        ForEach(packs, id: \.id) { pack in
                            SparkPackButton(
                                name: pack.name,
                                sparks: pack.amount,
                                price: pack.price,
                                loading: loadingPack == pack.id,
                                action: { buy(pack: pack.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    if !auth.isAuthenticated {
                        Text("Sign in to purchase sparks")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Text("Secure checkout via Stripe")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))

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
            #if os(iOS)
            .sheet(item: Binding(
                get: { checkoutURL.map(IdentifiableURL.init) },
                set: { checkoutURL = $0?.url }
            )) { wrapper in
                SafariView(url: wrapper.url)
                    .ignoresSafeArea()
                    .onDisappear {
                        // User returned from checkout — refresh balance from Firestore.
                        Task { await auth.refreshSparks() }
                    }
            }
            #endif
        }
    }

    // MARK: - Actions

    private func buy(pack: String) {
        guard auth.isAuthenticated, let user = auth.currentUser else {
            errorMessage = "Please sign in first"
            return
        }
        errorMessage = nil
        loadingPack = pack
        Task {
            do {
                let resp = try await APIService.shared.createCheckoutSession(
                    pack: pack, uid: user.uid, email: user.email
                )
                if let urlString = resp.url, let url = URL(string: urlString) {
                    checkoutURL = url
                } else {
                    errorMessage = "Checkout failed"
                }
            } catch {
                errorMessage = "Checkout unavailable"
            }
            loadingPack = nil
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SparkPackButton: View {
    let name: String
    let sparks: String
    let price: String
    var loading: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\u{26A1} \(sparks) sparks")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }

                Spacer()

                Group {
                    if loading {
                        ProgressView().tint(.white)
                    } else {
                        Text(price)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.purple)
                .cornerRadius(8)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
        .disabled(loading)
    }
}

// MARK: - Safari view

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
