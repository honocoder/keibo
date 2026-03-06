import SwiftUI

// MARK: - Color Palette

extension Color {
    /// Main purple-indigo accent used for interactive elements.
    static let sillageAccent = Color(red: 0.42, green: 0.30, blue: 0.92)
    /// Soft indigo gradient end.
    static let sillageAccentSecondary = Color(red: 0.55, green: 0.38, blue: 1.0)
    /// Mint green for healthy / under-budget state.
    static let sillageSuccess = Color(red: 0.18, green: 0.78, blue: 0.60)
    /// Amber for warning (75–100 % spent).
    static let sillageWarning = Color(red: 1.0,  green: 0.70, blue: 0.20)
    /// Coral red for over-budget state.
    static let sillageDanger  = Color(red: 1.0,  green: 0.35, blue: 0.38)
    /// Soft blue for savings.
    static let sillageSavings = Color(red: 0.25, green: 0.60, blue: 1.0)

    /// Card fill color based on spending progress (0…1+).
    static func envelopeFill(progress: Double) -> Color {
        switch progress {
        case ..<0.75: return .sillageAccent
        case ..<1.0:  return .sillageWarning
        default:      return .sillageDanger
        }
    }
}

// MARK: - Design Tokens

enum DS {
    /// Corner radius used for cards and sheets.
    static let cornerRadius: CGFloat = 22
    /// Corner radius for inner elements.
    static let innerRadius: CGFloat  = 14
    /// Standard horizontal/vertical padding for screens.
    static let pagePadding: CGFloat  = 20
    /// Padding inside cards.
    static let cardPadding: CGFloat  = 16
    /// Spacing between grid items.
    static let gridSpacing: CGFloat  = 14
    /// FAB size.
    static let fabSize: CGFloat      = 60
}

// MARK: - Glassmorphism Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = DS.cornerRadius
    var tintColor: Color      = .clear

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    if tintColor != .clear {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tintColor.opacity(0.06))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 6)
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = DS.cornerRadius,
        tintColor: Color = .clear
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tintColor: tintColor))
    }
}

// MARK: - Number formatting

extension Double {
    /// Formats a currency amount using the given ISO-4217 code.
    func formatted(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle          = .currency
        formatter.currencyCode         = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Haptic helpers

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let t = trailing {
                Text(t)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.pagePadding * 2)
        .frame(maxWidth: .infinity)
    }
}
