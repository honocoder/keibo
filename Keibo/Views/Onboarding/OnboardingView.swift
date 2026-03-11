import SwiftUI

// MARK: - Onboarding Entry Point

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background gradient (same as LockScreen)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.10, green: 0.07, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.sillageAccent : Color.white.opacity(0.25))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Pages
                TabView(selection: $currentPage) {
                    OnboardingPageView(page: .welcome).tag(0)
                    OnboardingPageView(page: .zeroBased).tag(1)
                    OnboardingPageView(page: .categories).tag(2)
                    OnboardingPageView(page: .addExpense).tag(3)
                    OnboardingPageView(page: .ready).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                            Haptics.selection()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(width: 54, height: 54)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Circle())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation { currentPage += 1 }
                            Haptics.selection()
                        } else {
                            Haptics.notification(.success)
                            onComplete()
                        }
                    } label: {
                        Text(currentPage < totalPages - 1 ? "Suivant" : "Commencer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [.sillageAccent, .sillageAccentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                            .shadow(color: .sillageAccent.opacity(0.4), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Page Model

private enum OnboardingPage {
    case welcome, zeroBased, categories, addExpense, ready

    var icon: String {
        switch self {
        case .welcome:    return "s.circle.fill"
        case .zeroBased:  return "arrow.3.trianglepath"
        case .categories: return "rectangle.3.group.fill"
        case .addExpense: return "plus.circle.fill"
        case .ready:      return "checkmark.seal.fill"
        }
    }

    var title: String {
        switch self {
        case .welcome:    return "Bienvenue dans Keibo"
        case .zeroBased:  return "Le Budget Base-Zéro"
        case .categories: return "3 types de catégories"
        case .addExpense: return "Ajoute en 3 secondes"
        case .ready:      return "C'est parti !"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "L'app qui donne un rôle à chaque euro."
        case .zeroBased:
            return "Revenu − Dépenses = 0"
        case .categories:
            return "Chaque dépense a sa place"
        case .addExpense:
            return "Bouton + en bas de l'écran"
        case .ready:
            return "Configure ton revenu et c'est parti !"
        }
    }

    var iconColor: [Color] {
        switch self {
        case .welcome:    return [.sillageAccent, .sillageAccentSecondary]
        case .zeroBased:  return [Color(red: 0.3, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)]
        case .categories: return [.sillageAccent, .sillageAccentSecondary]
        case .addExpense: return [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.4, blue: 0.3)]
        case .ready:      return [Color(red: 0.3, green: 0.8, blue: 0.5), Color(red: 0.2, green: 0.7, blue: 0.4)]
        }
    }
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                // Icon
                ZStack {
                    Circle()
                        .fill(page.iconColor[0].opacity(0.15))
                        .frame(width: 130, height: 130)
                        .blur(radius: isAnimating ? 20 : 10)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)

                    Image(systemName: page.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: page.iconColor,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.05 : 0.97)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                }

                // Title + subtitle
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(page.subtitle)
                        .font(.title3)
                        .foregroundStyle(page.iconColor[0])
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }

                // Content card
                pageContent
                    .padding(.horizontal, DS.pagePadding)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, DS.pagePadding)
        }
        .onAppear { isAnimating = true }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .welcome:
            welcomeContent
        case .zeroBased:
            zeroBasedContent
        case .categories:
            categoriesContent
        case .addExpense:
            addExpenseContent
        case .ready:
            readyContent
        }
    }

    // MARK: Welcome

    private var welcomeContent: some View {
        VStack(spacing: 16) {
            OnboardingCard(icon: "eurosign.circle.fill", color: .sillageAccent) {
                Text("Keibo utilise la méthode du **budget base-zéro** — chaque euro de ton revenu est intentionnellement assigné avant d'être dépensé.")
                    .foregroundStyle(.white.opacity(0.85))
            }
            OnboardingCard(icon: "chart.line.uptrend.xyaxis", color: .sillageSuccess) {
                Text("Résultat : **zéro surprise** en fin de mois, plus d'épargne, et une vraie visibilité sur ton argent.")
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: Zero-Based

    private var zeroBasedContent: some View {
        VStack(spacing: 16) {
            OnboardingCard(icon: "equal.circle.fill", color: .sillageSuccess) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Le principe")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("**Revenu** − Charges fixes − Enveloppes variables − Épargne **= 0**")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            OnboardingCard(icon: "lightbulb.fill", color: Color(red: 0.9, green: 0.7, blue: 0.2)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pourquoi ça marche ?")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("En assignant chaque euro à l'avance, tu prends des décisions conscientes — plus de dépenses « invisibles ».")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            OnboardingCard(icon: "arrow.clockwise.circle.fill", color: .sillageAccent) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chaque mois repart à zéro")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Le solde non dépensé est reporté au cycle suivant comme solde de départ.")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    // MARK: Categories

    private var categoriesContent: some View {
        VStack(spacing: 12) {
            CategoryTypeCard(
                icon: "lock.fill",
                color: Color(red: 0.4, green: 0.5, blue: 0.9),
                type: "Charges fixes",
                description: "Loyer, assurances, abonnements… Des montants constants chaque mois."
            )
            CategoryTypeCard(
                icon: "cart.fill",
                color: Color(red: 0.9, green: 0.5, blue: 0.2),
                type: "Enveloppes variables",
                description: "Courses, restaurants, loisirs… Tu définis un plafond et tu surveilles ta consommation."
            )
            CategoryTypeCard(
                icon: "banknote.fill",
                color: Color(red: 0.3, green: 0.75, blue: 0.5),
                type: "Épargne",
                description: "Tes objectifs à long terme. L'argent mis de côté chaque mois."
            )
        }
    }

    // MARK: Add Expense

    private var addExpenseContent: some View {
        VStack(spacing: 16) {
            StepCard(number: "1", text: "Appuie sur le **+** en bas de l'écran")
            StepCard(number: "2", text: "Entre le **montant** de ta dépense")
            StepCard(number: "3", text: "Choisis une **catégorie** et valide")
            OnboardingCard(icon: "arrow.left.and.right.circle.fill", color: .secondary.opacity(0.6)) {
                Text("Tu peux aussi faire **glisser vers la gauche** dans l'historique pour modifier ou supprimer une dépense.")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.subheadline)
            }
        }
    }

    // MARK: Ready

    private var readyContent: some View {
        VStack(spacing: 16) {
            OnboardingCard(icon: "1.circle.fill", color: .sillageAccent) {
                Text("Va dans **Budget** et configure ton revenu mensuel (icône crayon).")
                    .foregroundStyle(.white.opacity(0.85))
            }
            OnboardingCard(icon: "2.circle.fill", color: Color(red: 0.9, green: 0.6, blue: 0.2)) {
                Text("Ajuste les **catégories** selon ton style de vie dans Réglages.")
                    .foregroundStyle(.white.opacity(0.85))
            }
            OnboardingCard(icon: "3.circle.fill", color: .sillageSuccess) {
                Text("Commence à **enregistrer tes dépenses** au fil de la journée.")
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Reusable Onboarding Subviews

private struct OnboardingCard<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            content()
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.cardPadding)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: DS.innerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.innerRadius)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct CategoryTypeCard: View {
    let icon: String
    let color: Color
    let type: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(type)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: DS.innerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.innerRadius)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct StepCard: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.sillageAccent.opacity(0.20))
                    .frame(width: 40, height: 40)
                Text(number)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.sillageAccent)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.cardPadding)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: DS.innerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.innerRadius)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
