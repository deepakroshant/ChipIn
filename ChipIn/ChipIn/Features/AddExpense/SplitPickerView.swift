import SwiftUI

struct SplitPickerView: View {
    @Binding var splitType: SplitType

    private let options: [(SplitType, String, String)] = [
        (.equal, "Equal", "person.2"),
        (.percent, "Percent", "percent"),
        (.exact, "Exact", "dollarsign"),
        (.byItem, "By Item", "list.bullet"),
        (.shares, "Shares", "chart.pie")
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 76, maximum: 120), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(options, id: \.0.rawValue) { type, label, icon in
                Button {
                    splitType = type
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.headline)
                        Text(label)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(chipBackground(selected: splitType == type))
                    .foregroundStyle(splitType == type ? ChipInTheme.onPrimary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                splitType == type ? Color.clear : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: splitType == type ? ChipInTheme.accent.opacity(0.22) : .clear, radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func chipBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ChipInTheme.ctaGradient)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ChipInTheme.elevated)
        }
    }
}
