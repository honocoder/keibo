import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var budget: BudgetManager
    @EnvironmentObject private var auth: AuthManager

    @Query private var configs: [UserConfig]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \BudgetCycle.startDate, order: .reverse) private var cycles: [BudgetCycle]

    // Editing state (mirrors UserConfig, saved on change)
    @State private var startDay: Int     = 28
    @State private var currency: String  = "EUR"
    @State private var biometric: Bool   = false

    // Sheet state
    @State private var showResetAlert    = false
    @State private var showOnboarding    = false
    @State private var editingCategory: Category? = nil

    private var config: UserConfig? { configs.first }

    private let currencies = ["EUR", "USD", "GBP", "CHF", "CAD", "JPY"]
    private let days = Array(1...31)

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Cycle
                Section {
                    cycleStartPicker
                } header: {
                    Text("Cycle budgétaire")
                } footer: {
                    Text("Le cycle démarre le \(startDay) de chaque mois. Cycle actuel : \(budget.cycleStart.formatted(date: .abbreviated, time: .omitted)) → \(budget.cycleEnd.formatted(date: .abbreviated, time: .omitted)).")
                }

                // MARK: Devise
                Section("Devise") {
                    Picker("Devise", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: currency) { _, v in config?.currencyCode = v }
                }

                // MARK: Security
                Section {
                    Toggle(isOn: $biometric) {
                        Label(auth.biometryType == .faceID ? "Face ID" : "Touch ID",
                              systemImage: auth.biometryType == .faceID ? "faceid" : "touchid")
                    }
                    .onChange(of: biometric) { _, v in
                        config?.isBiometricAuthEnabled = v
                    }
                    .disabled(auth.biometryType == .none)
                } header: {
                    Text("Sécurité")
                } footer: {
                    if auth.biometryType == .none {
                        Text("La biométrie n'est pas disponible sur cet appareil.")
                    }
                }

                // MARK: Categories management
                Section("Catégories") {
                    ForEach(categories) { cat in
                        Button {
                            editingCategory = cat
                        } label: {
                            HStack {
                                Image(systemName: cat.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(.sillageAccent)
                                Text(cat.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(cat.targetAmount.formatted(currencyCode: currency))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(cat.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { categories[$0] }.forEach { context.delete($0) }
                    }
                    .onMove { from, to in
                        var sorted = categories
                        sorted.move(fromOffsets: from, toOffset: to)
                        for (i, cat) in sorted.enumerated() { cat.sortOrder = i }
                    }
                }

                // MARK: Cycles history
                if !cycles.isEmpty {
                    Section("Historique des cycles") {
                        ForEach(cycles.prefix(6)) { cycle in
                            CycleHistoryRow(cycle: cycle, currency: currency)
                        }
                    }
                }

                // MARK: Danger zone
                Section("Données") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Réinitialiser toutes les données", systemImage: "trash")
                    }
                }

                // MARK: About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Sillage")
                        Spacer()
                        Text("Budget Base-Zéro")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("À propos")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { EditButton() }
            .sheet(item: $editingCategory) { cat in
                EditCategorySheet(category: cat, currencyCode: currency)
            }
            .alert("Réinitialiser ?", isPresented: $showResetAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Réinitialiser", role: .destructive) { resetAllData() }
            } message: {
                Text("Toutes les catégories, transactions et cycles seront définitivement supprimés.")
            }
        }
        .onAppear { loadConfig() }
    }

    // MARK: - Subviews

    private var cycleStartPicker: some View {
        HStack {
            Text("Jour de démarrage")
            Spacer()
            Picker("", selection: $startDay) {
                ForEach(days, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: startDay) { _, v in
                config?.startDayOfMonth = v
                budget.refreshCycle(startDay: v)
            }
        }
    }

    // MARK: - Logic

    private func loadConfig() {
        guard let c = config else {
            // First launch — seed defaults
            seedDefaults()
            return
        }
        startDay  = c.startDayOfMonth
        currency  = c.currencyCode
        biometric = c.isBiometricAuthEnabled
    }

    /// Whether we already seeded defaults this session (prevents infinite recursion).
    @State private var didSeed = false

    private func resetAllData() {
        categories.forEach   { context.delete($0) }
        cycles.forEach       { context.delete($0) }
        // Keep config but reset values
        config?.monthlyIncome = 0
        Haptics.notification(.warning)
    }

    private func seedDefaults() {
        guard !didSeed else { return }
        didSeed = true

        let cfg = UserConfig()
        context.insert(cfg)

        let defaultCategories: [(String, String, CategoryType, Double)] = [
            ("Loyer",       "house.fill",            .fixed,    800),
            ("Internet",    "wifi",                  .fixed,    40),
            ("Téléphone",   "iphone",                .fixed,    20),
            ("Courses",     "cart.fill",             .variable, 300),
            ("Restaurants", "fork.knife",            .variable, 120),
            ("Transport",   "car.fill",              .variable, 80),
            ("Loisirs",     "gamecontroller.fill",   .variable, 60),
            ("Santé",       "cross.fill",            .variable, 30),
            ("Livret A",    "banknote",              .savings,  2000),
        ]

        for (i, (name, icon, type, target)) in defaultCategories.enumerated() {
            context.insert(Category(name: name, icon: icon, type: type, targetAmount: target, sortOrder: i))
        }

        // Apply defaults to local state directly (don't call loadConfig
        // again since @Query hasn't refreshed yet).
        startDay  = cfg.startDayOfMonth
        currency  = cfg.currencyCode
        biometric = cfg.isBiometricAuthEnabled
    }
}

// MARK: - Cycle History Row

struct CycleHistoryRow: View {
    let cycle: BudgetCycle
    let currency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cycle.startDate.formatted(.dateTime.day().month(.abbreviated))) – \(cycle.endDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.subheadline)
                if cycle.rolloverAmount > 0 {
                    Text("Report : +\(cycle.rolloverAmount.formatted(currencyCode: currency))")
                        .font(.caption)
                        .foregroundStyle(.sillageSuccess)
                }
            }
            Spacer()
            Text(cycle.effectiveIncome.formatted(currencyCode: currency))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Edit Category Sheet

struct EditCategorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let currencyCode: String

    @State private var name: String = ""
    @State private var target: String = ""
    @State private var initialBalance: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Nom de la catégorie", text: $name)
                }
                Section(category.type == .savings ? "Objectif mensuel" : "Budget cible") {
                    TextField("0", text: $target)
                        .keyboardType(.decimalPad)
                }
                if category.type == .savings {
                    Section {
                        TextField("0", text: $initialBalance)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("Solde initial")
                    } footer: {
                        Text("Montant déjà présent sur ce compte avant d'utiliser l'app.")
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Supprimer cette catégorie", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Modifier la catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        category.name = name
                        category.targetAmount = parseDecimal(target)
                        if category.type == .savings {
                            category.initialBalance = parseDecimal(initialBalance)
                        }
                        Haptics.notification(.success)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Supprimer « \(category.name) » ?", isPresented: $showDeleteConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    context.delete(category)
                    Haptics.notification(.warning)
                    dismiss()
                }
            } message: {
                Text("La catégorie et toutes ses transactions seront supprimées.")
            }
            .onAppear {
                name = category.name
                target = category.targetAmount > 0 ? formatForEditing(category.targetAmount) : ""
                initialBalance = category.initialBalance > 0 ? formatForEditing(category.initialBalance) : ""
            }
        }
        .presentationDetents([.medium])
    }

    private func parseDecimal(_ text: String) -> Double {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let value = formatter.number(from: text) {
            return value.doubleValue
        }
        return Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func formatForEditing(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
