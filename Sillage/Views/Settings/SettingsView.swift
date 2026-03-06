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
    @State private var income: String    = ""
    @State private var currency: String  = "EUR"
    @State private var biometric: Bool   = false

    // Sheet state
    @State private var showResetAlert    = false
    @State private var showOnboarding    = false

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

                // MARK: Revenue
                Section("Revenu mensuel") {
                    HStack {
                        Text("Revenu net")
                        Spacer()
                        TextField("2 500", text: $income)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: income) { _, _ in saveIncome() }
                    }

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
                        HStack {
                            Image(systemName: cat.icon)
                                .frame(width: 24)
                                .foregroundStyle(.sillageAccent)
                            Text(cat.name)
                            Spacer()
                            Text(cat.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
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
        income    = c.monthlyIncome > 0 ? String(c.monthlyIncome) : ""
        currency  = c.currencyCode
        biometric = c.isBiometricAuthEnabled
    }

    private func saveIncome() {
        config?.monthlyIncome = Double(income) ?? 0
    }

    private func resetAllData() {
        categories.forEach   { context.delete($0) }
        cycles.forEach       { context.delete($0) }
        // Keep config but reset values
        config?.monthlyIncome = 0
        Haptics.notification(.warning)
    }

    private func seedDefaults() {
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
            ("Livret A",    "banknote.fill",         .savings,  2000),
        ]

        for (i, (name, icon, type, target)) in defaultCategories.enumerated() {
            context.insert(Category(name: name, icon: icon, type: type, targetAmount: target, sortOrder: i))
        }
        loadConfig()
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
