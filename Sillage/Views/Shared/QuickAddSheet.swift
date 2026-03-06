import SwiftUI
import SwiftData

/// Bottom sheet for adding a transaction in < 3 seconds.
struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject private var budget: BudgetManager

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // Input state
    @State private var amountText: String   = ""
    @State private var note: String         = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedDate: Date   = .now
    @State private var showDatePicker       = false

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Amount Display
                amountHeader

                Divider().padding(.horizontal)

                ScrollView {
                    VStack(spacing: DS.gridSpacing * 1.5) {
                        // MARK: Category picker
                        categoryPicker

                        // MARK: Note field
                        noteField

                        // MARK: Date row
                        dateRow

                        Spacer(minLength: 80)
                    }
                    .padding(DS.pagePadding)
                }

                // MARK: Validate button
                validateButton
            }
            .navigationTitle("Nouvelle dépense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var amountHeader: some View {
        VStack(spacing: 6) {
            Text(amountText.isEmpty ? "0" : amountText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(amountText.isEmpty ? .tertiary : .primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: amountText)
            Text(selectedCategory.map { $0.name } ?? "Sélectionne une catégorie")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)

        // Numeric keypad
        .overlay(alignment: .bottom) {
            NumericKeypad(text: $amountText)
                .padding(.top, 96)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Catégorie")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(categories.filter { $0.type != .savings }) { cat in
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
        Button {
            save()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Valider \(amount > 0 ? amount.formatted(currencyCode: "EUR") : "")")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: amount > 0 ? [.sillageAccent, .sillageAccentSecondary] : [Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
            .padding(DS.pagePadding)
            .shadow(color: amount > 0 ? .sillageAccent.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(amount <= 0)
        .animation(.spring(response: 0.3), value: amount > 0)
    }

    // MARK: - Logic

    private func save() {
        guard amount > 0 else { return }
        let tx = Transaction(amount: amount, date: selectedDate, note: note, category: selectedCategory)
        context.insert(tx)
        Haptics.impact(.medium)
        Haptics.notification(.success)
        dismiss()
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

// MARK: - Numeric Keypad

struct NumericKeypad: View {
    @Binding var text: String

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(label: key) {
                            handleKey(key)
                        }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        Haptics.impact(.light)
        switch key {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case ".":
            if !text.contains(".") { text += text.isEmpty ? "0." : "." }
        default:
            // Max 2 decimal places
            if let dotIdx = text.firstIndex(of: ".") {
                let decimals = text.distance(from: text.index(after: dotIdx), to: text.endIndex)
                if decimals >= 2 { return }
            }
            if text == "0" { text = key } else { text += key }
        }
    }
}

private struct KeyButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.primary.opacity(0.04))
        }
        .buttonStyle(.plain)
    }
}
