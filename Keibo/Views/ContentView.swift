import SwiftUI
import SwiftData

/// Root view — shows the auth lock screen if required, otherwise the main TabView.
struct ContentView: View {
    @EnvironmentObject private var budget: BudgetManager
    @EnvironmentObject private var auth:   AuthManager

    @Query private var configs: [UserConfig]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var config: UserConfig? { configs.first }

    var body: some View {
        Group {
            if config?.isBiometricAuthEnabled == true && !auth.isUnlocked {
                LockScreen()
            } else {
                MainTabView()
                    .fullScreenCover(isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    )) {
                        OnboardingView { hasCompletedOnboarding = true }
                    }
            }
        }
        .onAppear {
            guard let cfg = config else { return }
            budget.refreshCycle(startDay: cfg.startDayOfMonth)
            if !cfg.isBiometricAuthEnabled {
                auth.unlockWithoutAuth()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Budget", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(0)

                SavingsView()
                    .tabItem {
                        Label("Épargne", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)

                SubscriptionsView()
                    .tabItem {
                        Label("Abonnements", systemImage: "repeat.circle.fill")
                    }
                    .tag(2)

                HistoryView()
                    .tabItem {
                        Label("Historique", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Réglages", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.sillageAccent)

            FloatingActionButton { showQuickAdd = true }
                .padding(.bottom, 64)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
        }
    }
}

// MARK: - Lock Screen

struct LockScreen: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.10, green: 0.07, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo area
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.sillageAccent.opacity(0.20))
                            .frame(width: 100, height: 100)
                            .blur(radius: isAnimating ? 16 : 8)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                        Image(systemName: "s.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.sillageAccent, .sillageAccentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Keibo")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Budget Base-Zéro")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Auth button
                VStack(spacing: 16) {
                    if let errorMsg = auth.authError {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.sillageDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await auth.authenticate() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: auth.biometryType == .faceID ? "faceid" : "touchid")
                                .font(.title3)
                            Text(auth.biometryType == .faceID ? "Déverrouiller avec Face ID" : "Déverrouiller avec Touch ID")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.sillageAccent, .sillageAccentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                        .shadow(color: .sillageAccent.opacity(0.4), radius: 16, y: 6)
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .buttonStyle(.plain)

                    Button("Utiliser le code") {
                        Task { await auth.authenticate(reason: "Déverrouille Keibo avec ton code") }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            isAnimating = true
            Task { await auth.authenticate() }
        }
    }
}
