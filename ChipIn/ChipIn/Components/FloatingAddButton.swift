import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(ChipInTheme.onPrimary)
                .frame(width: 56, height: 56)
                .background(ChipInTheme.ctaGradient)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ChipInTheme.background, lineWidth: 4)
                )
                .shadow(color: ChipInTheme.accent.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}
