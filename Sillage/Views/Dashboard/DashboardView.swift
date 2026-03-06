import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var budget: BudgetManager

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \BudgetCycle.startDate, order: .reverse) private var cycles: [BudgetCycle]
    @Query private var configs: [UserConfig]

    @State private var showQuickAdd   = false
    @State private var showAddCat     = false

    private var config: UserConfig? { configs.first }
    private var currencyCode: String { config?.currencyCode ?? "EUR" }

    private var currentCycle: BudgetCycle? {
        cycles.first { $0.startDate == budget.cycleStart }
    }

    private var effectiveIncome: Double {
        currentCycle?.effectiveIncome ?? (config?.monthlyIncome ?? 0)
    }

    private var fixedCategories: [Category] {
        categories.filter { $0.type == .fixed }
    }
    private var variableCategories: [Category] {
        categories.filter { $0.type == .variable }
    }

    private var remaining: Double {
        budget.remainingBudget(effectiveIncome: effectiveIncome, categories: categories)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DS.gridSpacing * 1.5) {
                        // MARK: Cycle Banner
                        cycleBanner

                        // MARK: "Reste à dépenser" Hero
                        remainingHero

                        // MARK: Fixed Expenses
                        if !fixedCategories.isEmpty {
                            fixedSection
                        }

                        // MARK: Envelopes Grid
                        if !variableCategories.isEmpty {
                            envelopesSection
                        }

                        if categories.isEmpty {
                            EmptyStateView(
                                icon: "rectangle.stack.badge.plus",
                                title: "Aucune catégorie",
                                subtitle: "Ajoute des catégories dans les Réglages pour démarrer."
                            )
                        }

                        // Bottom padding for FAB
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, 8)
                }

                // MARK: FAB
                FloatingActionButton { showQuickAdd = true }
                    .padding(.bottom, 24)
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCat = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet()
            }
            .sheet(isPresented: $showAddCat) {
                AddCategorySheet()
            }
            .onAppear {
                if let startDay = config?.startDayOfMonth {
                    budget.refreshCycle(startDay: startDay)
                }
                budget.ensureCurrentCycle(
                    in: context,
                    allCycles: cycles,
                    baseIncome: config?.monthlyIncome ?? 0
                )
            }
        }
    }

    // MARK: - Subviews

    private var cycleBanner: some View {
        HStack {
            Image(systemName: "calendar.circle.fill")
                .foregroundStyle(.sillageAccent)
            Text("Cycle \(budget.cycleStart.formatted(.dateTime.day().month(.abbreviated))) → \(budget.cycleEnd.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if let rollover = currentCycle?.rolloverAmount, rollover > 0 {
                Text("+\(rollover.formatted(currencyCode: currencyCode)) report")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.sillageSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.sillageSuccess.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(DS.cardPadding)
        .glassCard(cornerRadius: DS.innerRadius)
    }

    private var remainingHero: some View {
        VStack(spacing: 8) {
            Text("Reste à dépenser")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(remaining.formatted(currencyCode: currencyCode))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: remaining >= 0
                            ? [.sillageAccent, .sillageAccentSecondary]
                            : [.sillageDanger, .sillageDanger.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .contentTransition(.numericText(countsDown: remaining < 0))
                .animation(.spring(response: 0.5), value: remaining)

            // Mini budget summary bar
            if effectiveIncome > 0 {
                let spentRatio = min(budget.totalSpent(categories: categories) / effectiveIncome, 1)
                HStack(spacing: 4) {
                    Text(budget.totalSpent(categories: categories).formatted(currencyCode: currencyCode) + " dépensé")
                    Text("·")
                    Text(effectiveIncome.formatted(currencyCode: currencyCode) + " revenu")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ProgressBar(progress: spentRatio, color: .envelopeFill(progress: spentRatio))
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, DS.cardPadding)
        .glassCard()
    }

    private var fixedSection: some View {
        VStack(alignment: .leading, spacing: DS.gridSpacing) {
            SectionHeader(
                title: "Dépenses fixes",
                trailing: "\(fixedCategories.filter { budget.spent(for: $0) >= $0.targetAmount }.count)/\(fixedCategories.count) payées"
            )
            ForEach(fixedCategories) { cat in
                FixedExpenseRow(
                    category: cat,
                    spent: budget.spent(for: cat),
                    currencyCode: currencyCode
                ) {
                    toggleFixedPayment(for: cat)
                }
            }
        }
    }

    private var envelopesSection: some View {
        VStack(alignment: .leading, spacing: DS.gridSpacing) {
            SectionHeader(title: "Enveloppes")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.gridSpacing),
                    GridItem(.flexible(), spacing: DS.gridSpacing)
                ],
                spacing: DS.gridSpacing
            ) {
                ForEach(variableCategories) { cat in
                    NavigationLink(destination: CategoryDetailView(category: cat, currencyCode: currencyCode)) {
                        EnvelopeCard(
                            category: cat,
                            spent: budget.spent(for: cat),
                            currencyCode: currencyCode
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Logic

    /// Toggle fixed expense: if unpaid, add a full-amount transaction; if paid, remove it.
    private func toggleFixedPayment(for category: Category) {
        let alreadyPaid = budget.spent(for: category) >= category.targetAmount

        if alreadyPaid {
            // Remove the most recent cycle transaction for this category
            let toRemove = category.transactions
                .filter { $0.date >= budget.cycleStart && $0.date <= budget.cycleEnd }
                .sorted { $0.date > $1.date }
                .first
            if let tx = toRemove { context.delete(tx) }
        } else {
            // Add a transaction for the full target amount
            let tx = Transaction(amount: category.targetAmount, date: .now, note: "Paiement automatique", category: category)
            context.insert(tx)
        }
        Haptics.impact(.medium)
    }
}

// MARK: - Category Detail

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var budget: BudgetManager
    let category: Category
    let currencyCode: String

    @State private var showQuickAdd = false

    private var cycleTransactions: [Transaction] {
        category.transactions
            .filter { $0.date >= budget.cycleStart && $0.date <= budget.cycleEnd }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                EnvelopeCard(
                    category: category,
                    spent: budget.spent(for: category),
                    currencyCode: currencyCode
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section("Transactions du cycle") {
                if cycleTransactions.isEmpty {
                    Text("Aucune transaction ce cycle.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(cycleTransactions) { tx in
                        TransactionRow(tx: tx, currencyCode: currencyCode)
                    }
                    .onDelete { indexSet in
                        indexSet.map { cycleTransactions[$0] }.forEach { context.delete($0) }
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showQuickAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
        }
    }
}

// MARK: - TransactionRow

struct TransactionRow: View {
    let tx: Transaction
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.note.isEmpty ? "Dépense" : tx.note)
                    .font(.subheadline)
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(tx.amount.formatted(currencyCode: currencyCode))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String       = ""
    @State private var icon: String       = "tag.fill"
    @State private var type: CategoryType = .variable
    @State private var target: String     = ""

    private let icons = [
        "cart.fill", "house.fill", "car.fill", "fork.knife", "bolt.fill",
        "drop.fill", "iphone", "heart.fill", "airplane", "gamecontroller.fill",
        "book.fill", "music.note", "tshirt.fill", "figure.walk", "pawprint.fill",
        "cross.fill", "wrench.fill", "tv.fill", "gift.fill", "creditcard.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la catégorie", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(CategoryType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Budget cible (€)", text: $target)
                        .keyboardType(.decimalPad)
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { sf in
                            Button {
                                icon = sf
                                Haptics.selection()
                            } label: {
                                Image(systemName: sf)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(icon == sf ? Color.sillageAccent.opacity(0.18) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(icon == sf ? .sillageAccent : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let amount = Double(target) ?? 0
        let cat = Category(name: name, icon: icon, type: type, targetAmount: amount)
        context.insert(cat)
        Haptics.notification(.success)
        dismiss()
    }
}
