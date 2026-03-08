import SwiftUI
import SwiftData

// MARK: - Color helpers for SubscriptionCategory

extension SubscriptionCategory {
    var swiftUIColor: Color {
        switch self {
        case .videoStreaming: return Color(red: 0.90, green: 0.25, blue: 0.25)
        case .musicStreaming: return Color(red: 0.18, green: 0.78, blue: 0.42)
        case .gaming:         return Color(red: 0.25, green: 0.55, blue: 1.00)
        case .software:       return Color(red: 0.55, green: 0.38, blue: 1.00)
        case .cloudStorage:   return Color(red: 0.20, green: 0.70, blue: 0.90)
        case .healthFitness:  return Color(red: 1.00, green: 0.30, blue: 0.55)
        case .newsMedia:      return Color(red: 1.00, green: 0.65, blue: 0.10)
        case .other:          return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

// MARK: - Main View

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.createdAt) private var subscriptions: [Subscription]
    @Query private var configs: [UserConfig]

    @State private var showAddSheet       = false
    @State private var editingSubscription: Subscription?

    private var currencyCode: String { configs.first?.currencyCode ?? "EUR" }

    private var totalMonthly: Double { subscriptions.reduce(0) { $0 + $1.monthlyAmount } }
    private var totalAnnual:  Double { totalMonthly * 12 }

    /// Subscriptions grouped by category, skipping empty categories.
    private var grouped: [(SubscriptionCategory, [Subscription])] {
        SubscriptionCategory.allCases.compactMap { cat in
            let subs = subscriptions.filter { $0.category == cat }
            return subs.isEmpty ? nil : (cat, subs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.gridSpacing * 1.5) {
                    summaryCard

                    if subscriptions.isEmpty {
                        EmptyStateView(
                            icon: "repeat.circle",
                            title: "Aucun abonnement",
                            subtitle: "Ajoute tes abonnements pour visualiser tes dépenses récurrentes."
                        )
                    } else {
                        categorySections
                    }

                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, 8)
            }
            .navigationTitle("Abonnements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.sillageAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionSheet(currencyCode: currencyCode)
        }
        .sheet(item: $editingSubscription) { sub in
            AddSubscriptionSheet(currencyCode: currencyCode, editingSubscription: sub)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.sillageAccent)
                Spacer()
                Text("\(subscriptions.count) abonnement\(subscriptions.count > 1 ? "s" : "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(totalMonthly.formatted(currencyCode: currencyCode))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.sillageAccent, .sillageAccentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("/ mois")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text("Soit \(totalAnnual.formatted(currencyCode: currencyCode)) par an")
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(DS.cardPadding + 4)
        .glassCard(tintColor: .sillageAccent)
    }

    // MARK: - Category Sections

    private var categorySections: some View {
        VStack(alignment: .leading, spacing: DS.gridSpacing * 1.5) {
            ForEach(grouped, id: \.0) { category, subs in
                VStack(alignment: .leading, spacing: DS.gridSpacing) {
                    SectionHeader(
                        title: category.displayName,
                        trailing: "\(subs.count) abonnement\(subs.count > 1 ? "s" : "")"
                    )
                    ForEach(subs) { sub in
                        SubscriptionRow(
                            subscription: sub,
                            currencyCode: currencyCode
                        ) {
                            editingSubscription = sub
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(sub)
                                Haptics.notification(.warning)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subscription Row

struct SubscriptionRow: View {
    let subscription: Subscription
    let currencyCode: String
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(subscription.category.swiftUIColor.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: subscription.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(subscription.category.swiftUIColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subscription.billingCycle.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(subscription.amount.formatted(currencyCode: currencyCode))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    if subscription.billingCycle != .monthly {
                        Text("\(subscription.monthlyAmount.formatted(currencyCode: currencyCode))/mois")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add / Edit Sheet

struct AddSubscriptionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let currencyCode: String
    var editingSubscription: Subscription? = nil

    @State private var name         = ""
    @State private var amountText   = ""
    @State private var billingCycle = BillingCycle.monthly
    @State private var category     = SubscriptionCategory.other
    @State private var selectedIcon = "creditcard.fill"

    private var isEditing: Bool { editingSubscription != nil }

    private let availableIcons = [
        "creditcard.fill",  "tv.fill",          "music.note",       "gamecontroller.fill",
        "laptopcomputer",   "icloud.fill",       "heart.fill",       "newspaper.fill",
        "wifi",             "phone.fill",        "cart.fill",        "book.fill",
        "camera.fill",      "mic.fill",          "headphones",       "globe",
        "play.rectangle.fill", "film.fill",      "waveform",         "cloud.fill",
        "lock.shield.fill", "star.fill",         "bell.fill",        "paintbrush.fill"
    ]

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount > 0 }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Ex : Netflix, Spotify…", text: $name)
                }

                Section("Montant & fréquence") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Fréquence", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.displayName).tag(cycle)
                        }
                    }
                    if billingCycle != .monthly && parsedAmount > 0 {
                        HStack {
                            Text("Équivalent mensuel")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(billingCycle.monthlyAmount(for: parsedAmount).formatted(currencyCode: currencyCode) + "/mois")
                                .foregroundStyle(.sillageAccent)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }
                }

                Section("Catégorie") {
                    Picker("Catégorie", selection: $category) {
                        ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                Haptics.selection()
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon
                                                  ? Color.sillageAccent.opacity(0.2)
                                                  : Color.gray.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(
                                                selectedIcon == icon ? Color.sillageAccent : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .foregroundStyle(selectedIcon == icon ? .sillageAccent : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let sub = editingSubscription { context.delete(sub) }
                            Haptics.notification(.warning)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Supprimer l'abonnement")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvel abonnement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    private var currencySymbol: String {
        switch currencyCode {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "Fr."
        default:    return currencyCode
        }
    }

    private func loadExisting() {
        guard let sub = editingSubscription else { return }
        name         = sub.name
        amountText   = String(sub.amount)
        billingCycle = sub.billingCycle
        category     = sub.category
        selectedIcon = sub.icon
    }

    private func save() {
        if let sub = editingSubscription {
            sub.name         = name.trimmingCharacters(in: .whitespaces)
            sub.amount       = parsedAmount
            sub.billingCycle = billingCycle
            sub.category     = category
            sub.icon         = selectedIcon
        } else {
            let sub = Subscription(
                name:         name.trimmingCharacters(in: .whitespaces),
                amount:       parsedAmount,
                billingCycle: billingCycle,
                category:     category,
                icon:         selectedIcon
            )
            context.insert(sub)
        }
        Haptics.notification(.success)
        dismiss()
    }
}
