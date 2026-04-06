import SwiftUI

/// Animated shimmer placeholder for loading states.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var cornerRadius: CGFloat = 10
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(shimmerGradient)
            .frame(height: height)
            .onAppear {
                phase = -1
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        let base = ChipInTheme.elevated.opacity(0.6)
        let highlight = ChipInTheme.elevated
        // Animate gradient direction so stop locations stay in [0,1] and ordered (SwiftUI logs otherwise).
        let t = (phase + 1) / 2
        return LinearGradient(
            colors: [base, highlight, base],
            startPoint: UnitPoint(x: t - 0.55, y: 0.5),
            endPoint: UnitPoint(x: t + 0.55, y: 0.5)
        )
    }
}

/// A skeleton card row that looks like a PersonBalanceRow.
struct PersonBalanceRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            ShimmerView(cornerRadius: 20, height: 40)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 8) {
                ShimmerView(cornerRadius: 6, height: 13).frame(width: 120)
                ShimmerView(cornerRadius: 6, height: 11).frame(width: 80)
            }
            Spacer()
            ShimmerView(cornerRadius: 6, height: 16).frame(width: 60)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

/// A skeleton row for ActivityFeed.
struct ActivityRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ShimmerView(cornerRadius: 22, height: 44).frame(width: 44)
            VStack(alignment: .leading, spacing: 8) {
                ShimmerView(cornerRadius: 6, height: 13).frame(width: 180)
                ShimmerView(cornerRadius: 6, height: 11).frame(width: 120)
                ShimmerView(cornerRadius: 6, height: 10).frame(width: 60)
            }
            Spacer()
            ShimmerView(cornerRadius: 6, height: 14).frame(width: 50)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
