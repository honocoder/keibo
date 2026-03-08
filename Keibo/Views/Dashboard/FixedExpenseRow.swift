import SwiftUI

/// A row representing a fixed monthly expense (rent, internet, etc.).
/// Tapping the checkmark toggles whether the payment has been made this cycle.
struct FixedExpenseRow: View {
    let category: Category
    let spent: Double
    let currencyCode: String
    let onToggle: () -> Void

    private var isPaid: Bool { spent >= category.targetAmount }
    private var remaining: Double { max(0, category.targetAmount - spent) }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(isPaid ? Color.sillageSuccess.opacity(0.15) : Color.secondary.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isPaid ? .sillageSuccess : .secondary)
            }

            // Name + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isPaid ? .secondary : .primary)
                    .strikethrough(isPaid, color: .secondary)

                Text(isPaid
                     ? "Payé ✓"
                     : "Reste \(remaining.formatted(currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(isPaid ? .sillageSuccess : .secondary)
            }

            Spacer()

            // Amount + toggle
            VStack(alignment: .trailing, spacing: 4) {
                Text(category.targetAmount.formatted(currencyCode: currencyCode))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isPaid ? .secondary : .primary)

                // Paid toggle button
                Button {
                    Haptics.impact(.medium)
                    onToggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPaid ? Color.sillageSuccess : Color.secondary.opacity(0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: isPaid ? "checkmark" : "circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isPaid ? .white : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isPaid ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPaid)
            }
        }
        .padding(DS.cardPadding)
        .glassCard(cornerRadius: DS.innerRadius, tintColor: isPaid ? .sillageSuccess : .clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPaid)
    }
}
