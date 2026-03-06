import SwiftUI
import SwiftData

struct SavingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var budget: BudgetManager

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query private var configs: [UserConfig]

    @State private var showQuickAdd  = false
    @State private var showAddTarget = false

    private var currencyCode: String { configs.first?.currencyCode ?? "EUR" }
    private var savingsCategories: [Category] { allCategories.filter { $0.type == .savings } }

    private var totalSaved: Double {
        savingsCategories.reduce(0) { $0 + budget.totalSaved(for: $1) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DS.gridSpacing * 1.5) {
                        // Summary card
                        totalSummaryCard

                        // Savings accounts
                        if savingsCategories.isEmpty {
                            EmptyStateView(
                                icon: "banknote",
                                title: "Aucun compte d'épargne",
                                subtitle: "Ajoute un livret ou un compte d'investissement pour suivre ta progression."
                            )
                        } else {
                            VStack(alignment: .leading, spacing: DS.gridSpacing) {
                                SectionHeader(title: "Comptes & Livrets")
                                ForEach(savingsCategories) { cat in
                                    SavingsAccountCard(
                                        category: cat,
                                        totalSaved: budget.totalSaved(for: cat),
                                        cycleSaved: budget.spent(for: cat),
                                        currencyCode: currencyCode
                                    )
                                }
                            }
                        }

                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, 8)
                }

                FloatingActionButton { showQuickAdd = true }
                    .padding(.bottom, 24)
            }
            .navigationTitle("Épargne")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet()
            }
        }
    }

    // MARK: - Summary

    private var totalSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.sillageSavings)
                Spacer()
                Text("Total épargné")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(totalSaved.formatted(currencyCode: currencyCode))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.sillageSavings, .sillageAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
            }

            // This-cycle savings
            let cycleSavingsTotal = savingsCategories.reduce(0.0) { $0 + budget.spent(for: $1) }
            if cycleSavingsTotal > 0 {
                HStack {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                    Text("+\(cycleSavingsTotal.formatted(currencyCode: currencyCode)) ce cycle")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.sillageSuccess)
            }
        }
        .padding(DS.cardPadding + 4)
        .glassCard(tintColor: .sillageSavings)
    }
}

// MARK: - Savings Account Card

struct SavingsAccountCard: View {
    let category: Category
    let totalSaved: Double
    let cycleSaved: Double
    let currencyCode: String

    private var progress: Double {
        guard category.targetAmount > 0 else { return 0 }
        return totalSaved / category.targetAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.sillageSavings.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.sillageSavings)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name)
                        .font(.subheadline.weight(.semibold))
                    if category.targetAmount > 0 {
                        Text("Objectif \(category.targetAmount.formatted(currencyCode: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(totalSaved.formatted(currencyCode: currencyCode))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    if cycleSaved > 0 {
                        Text("+\(cycleSaved.formatted(currencyCode: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.sillageSuccess)
                    }
                }
            }

            if category.targetAmount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressBar(progress: progress, color: .sillageSavings)
                    HStack {
                        Text("\(Int(min(progress * 100, 100)))% de l'objectif")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if progress < 1 {
                            Text("Il manque \((category.targetAmount - totalSaved).formatted(currencyCode: currencyCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Objectif atteint! 🎉")
                                .font(.caption)
                                .foregroundStyle(.sillageSuccess)
                        }
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .glassCard(tintColor: .sillageSavings)
    }
}
