import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var budget: BudgetManager

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var configs: [UserConfig]

    @State private var searchText          = ""
    @State private var filterType          = FilterType.all
    @State private var editingTransaction: Transaction? = nil

    private var currencyCode: String { configs.first?.currencyCode ?? "EUR" }

    enum FilterType: String, CaseIterable {
        case all      = "Tout"
        case cycle    = "Ce cycle"
        case fixed    = "Fixes"
        case variable = "Variables"
        case savings  = "Épargne"
    }

    private var filtered: [Transaction] {
        allTransactions.filter { tx in
            // Text filter
            let matchesSearch = searchText.isEmpty ||
                tx.note.localizedCaseInsensitiveContains(searchText) ||
                (tx.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)

            // Type filter
            let matchesType: Bool
            switch filterType {
            case .all:      matchesType = true
            case .cycle:    matchesType = tx.date >= budget.cycleStart && tx.date <= budget.cycleEnd
            case .fixed:    matchesType = tx.category?.type == .fixed
            case .variable: matchesType = tx.category?.type == .variable
            case .savings:  matchesType = tx.category?.type == .savings
            }

            return matchesSearch && matchesType
        }
    }

    /// Transactions grouped by calendar day (most recent first).
    private var grouped: [(key: Date, value: [Transaction])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filtered) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return dict.sorted { $0.key > $1.key }
    }

    private var totalFiltered: Double {
        filtered.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterBar
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.vertical, 10)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "Aucune transaction",
                        subtitle: "Tes dépenses apparaîtront ici."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Summary
                        Section {
                            HStack {
                                Text("\(filtered.count) transaction\(filtered.count > 1 ? "s" : "")")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(totalFiltered.formatted(currencyCode: currencyCode))
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(.sillageAccent)
                            }
                            .font(.subheadline)
                        }

                        // Grouped by day
                        ForEach(grouped, id: \.key) { dayGroup in
                            Section(header: Text(dayGroup.key.formatted(.dateTime.weekday(.wide).day().month())).textCase(nil)) {
                                ForEach(dayGroup.value) { tx in
                                    TransactionRow(tx: tx, currencyCode: currencyCode)
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                editingTransaction = tx
                                                Haptics.selection()
                                            } label: {
                                                Label("Modifier", systemImage: "pencil")
                                            }
                                            .tint(.sillageAccent)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                context.delete(tx)
                                                Haptics.notification(.warning)
                                            } label: {
                                                Label("Supprimer", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Rechercher…")
            .sheet(item: $editingTransaction) { tx in
                QuickAddSheet(editingTransaction: tx)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { ft in
                    Button {
                        filterType = ft
                        Haptics.selection()
                    } label: {
                        Text(ft.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                filterType == ft
                                    ? AnyShapeStyle(LinearGradient(colors: [.sillageAccent, .sillageAccentSecondary], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.primary.opacity(0.07))
                            )
                            .foregroundStyle(filterType == ft ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: filterType)
                }
            }
        }
    }
}
