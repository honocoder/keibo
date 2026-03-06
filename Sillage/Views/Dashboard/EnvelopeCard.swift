import SwiftUI

/// A budget envelope card for variable-spend categories.
/// The card background fills up left-to-right as the budget is consumed.
struct EnvelopeCard: View {
    let category: Category
    let spent: Double
    let currencyCode: String

    private var target: Double  { category.targetAmount }
    private var remaining: Double { target - spent }
    private var progress: Double  { target > 0 ? spent / target : 0 }
    private var isOverBudget: Bool { progress > 1.0 }

    private var fillColor: Color { .envelopeFill(progress: progress) }

    var body: some View {
        ZStack(alignment: .leading) {
            // MARK: Progressive fill layer
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [fillColor.opacity(0.28), fillColor.opacity(0.10)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(progress, 1.0))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
            }

            // MARK: Content
            VStack(alignment: .leading, spacing: 10) {
                // Icon + alert badge
                HStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: category.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(fillColor)

                        if isOverBudget {
                            Circle()
                                .fill(Color.sillageDanger)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                    Spacer()
                    // Progress percentage
                    Text(progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(fillColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(fillColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Name
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Amounts
                VStack(alignment: .leading, spacing: 2) {
                    Text(spent.formatted(currencyCode: currencyCode))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("sur \(target.formatted(currencyCode: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Thin progress bar at bottom
                ProgressBar(progress: progress, color: fillColor)
            }
            .padding(DS.cardPadding)
        }
        .frame(height: 168)
        .glassCard(tintColor: isOverBudget ? .sillageDanger : .clear)
        .overlay(
            isOverBudget
                ? RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .strokeBorder(Color.sillageDanger.opacity(0.5), lineWidth: 1.5)
                : nil
        )
        // Shake animation when over budget
        .modifier(ShakeModifier(trigger: isOverBudget))
    }

    private var progressLabel: String {
        let pct = Int(min(progress * 100, 999))
        return "\(pct)%"
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(progress, 1.0))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 5)
        .clipShape(Capsule())
    }
}

// MARK: - Shake Modifier (over-budget alert)

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var shake = false

    func body(content: Content) -> some View {
        content
            .offset(x: shake ? 4 : 0)
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                withAnimation(.linear(duration: 0.07).repeatCount(4, autoreverses: true)) {
                    shake = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = false }
            }
    }
}
