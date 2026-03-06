import SwiftUI

/// The primary FAB that opens the QuickAddSheet.
struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            ZStack {
                // Glow
                Circle()
                    .fill(Color.sillageAccent.opacity(0.30))
                    .frame(width: DS.fabSize + 14, height: DS.fabSize + 14)
                    .blur(radius: 10)

                // Button face
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.sillageAccent, .sillageAccentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.fabSize, height: DS.fabSize)
                    .shadow(color: .sillageAccent.opacity(0.45), radius: 12, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
