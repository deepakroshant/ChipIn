import SwiftUI

struct EmptyStateView: View {
    let emoji: String
    let headline: String
    let subheadline: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ChipInTheme.elevated.opacity(0.6))
                    .frame(width: 88, height: 88)
                Text(emoji)
                    .font(.system(size: 42))
            }
            VStack(spacing: 6) {
                Text(headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ChipInTheme.label)
                    .multilineTextAlignment(.center)
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChipInTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(ChipInTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
