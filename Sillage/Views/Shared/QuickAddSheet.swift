import SwiftUI
import SwiftData

/// Bottom sheet for adding a transaction in < 3 seconds.
struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject private var budget: BudgetManager

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \BudgetCycle.startDate, order: .reverse) private var cycles: [BudgetCycle]

    enum TransactionMode: String, CaseIterable {
        case expense = "Dépense"
        case income  = "Revenu"
    }

    // Input state
    @State private var mode: TransactionMode = .expense
    @State private var amountText: String   = ""
    @State private var note: String         = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedDate: Date   = .now
    @State private var showDatePicker       = false

    private var amount: Double { parseDecimal(amountText) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.gridSpacing * 1.5) {
                    // MARK: Mode toggle
                    modePicker

                    // MARK: Amount input
                    amountField

                    // MARK: Category picker (expenses only)
                    if mode == .expense {
                        categoryPicker
                    }

                    // MARK: Note field
                    noteField

                    // MARK: Date row
                    dateRow

                    Spacer(minLength: 80)
                }
                .padding(DS.pagePadding)
            }
            .safeAreaInset(edge: .bottom) {
                validateButton
            }
            .navigationTitle(mode == .expense ? "Nouvelle dépense" : "Nouveau revenu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var modePicker: some View {
        Picker("", selection: $mode) {
            ForEach(TransactionMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Montant")
            HStack {
                Image(systemName: "eurosign.circle")
                    .foregroundStyle(.sillageAccent)
                TextField("0,00", text: $amountText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
            }
            .padding(DS.cardPadding)
            .glassCard(cornerRadius: DS.innerRadius)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Catégorie")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(categories) { cat in
                    CategoryChip(
                        category: cat,
                        isSelected: selectedCategory?.id == cat.id
                    ) {
                        Haptics.selection()
                        selectedCategory = (selectedCategory?.id == cat.id) ? nil : cat
                    }
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Note")
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                TextField("Optionnel…", text: $note)
                    .font(.body)
            }
            .padding(DS.cardPadding)
            .glassCard(cornerRadius: DS.innerRadius)
        }
    }

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Date")
            Button {
                withAnimation { showDatePicker.toggle() }
                Haptics.selection()
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.sillageAccent)
                    Text(selectedDate.formatted(date: .long, time: .omitted))
                        .font(.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                }
                .padding(DS.cardPadding)
                .glassCard(cornerRadius: DS.innerRadius)
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(DS.cardPadding)
                    .glassCard(cornerRadius: DS.innerRadius)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var validateButton: some View {
        let accentColors: [Color] = mode == .income
            ? [.sillageSuccess, .sillageSuccess.opacity(0.8)]
            : [.sillageAccent, .sillageAccentSecondary]

        return Button {
            save()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode == .income ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                Text(mode == .income
                     ? "Ajouter \(amount > 0 ? "+" + amount.formatted(currencyCode: "EUR") : "")"
                     : "Valider \(amount > 0 ? amount.formatted(currencyCode: "EUR") : "")")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: amount > 0 ? accentColors : [Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
            .padding(DS.pagePadding)
            .shadow(color: amount > 0 ? accentColors[0].opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(amount <= 0)
        .animation(.spring(response: 0.3), value: amount > 0)
        .animation(.spring(response: 0.3), value: mode)
    }

    // MARK: - Logic

    private func save() {
        guard amount > 0 else { return }

        if mode == .income {
            // Add extra income to the current cycle
            if let cycle = cycles.first(where: {
                $0.startDate == budget.cycleStart
            }) {
                cycle.extraIncome += amount
            }
        } else {
            let tx = Transaction(amount: amount, date: selectedDate, note: note, category: selectedCategory)
            context.insert(tx)
        }

        Haptics.impact(.medium)
        Haptics.notification(.success)
        dismiss()
    }

    /// Parses a decimal string accounting for locale (comma or dot as separator).
    private func parseDecimal(_ text: String) -> Double {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let value = formatter.number(from: text) {
            return value.doubleValue
        }
        return Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.sillageAccent : Color.secondary.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                Text(category.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .sillageAccent : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}


