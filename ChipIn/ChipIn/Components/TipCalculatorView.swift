import SwiftUI

struct TipCalculatorView: View {
    let subtotal: Decimal
    @Binding var tipAmount: Decimal

    @State private var selectedPercent: Int? = nil
    @State private var customText: String = ""
    @FocusState private var customFocused: Bool

    private let presets = [15, 18, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tip", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ChipInTheme.label)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { pct in
                    Button {
                        selectedPercent = pct
                        customText = ""
                        customFocused = false
                        tipAmount = (subtotal * Decimal(pct)) / 100
                    } label: {
                        Text("\(pct)%")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedPercent == pct ? ChipInTheme.accent : ChipInTheme.elevated)
                            .foregroundStyle(selectedPercent == pct ? ChipInTheme.onPrimary : ChipInTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                TextField("Custom", text: $customText)
                    .keyboardType(.decimalPad)
                    .focused($customFocused)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(customFocused ? ChipInTheme.accent.opacity(0.15) : ChipInTheme.elevated)
                    .foregroundStyle(ChipInTheme.label)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(customFocused ? ChipInTheme.accent : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: customText) { _, val in
                        selectedPercent = nil
                        if let d = Decimal(string: val), d >= 0 {
                            tipAmount = d
                        } else if val.isEmpty {
                            tipAmount = 0
                        }
                    }
            }

            if tipAmount > 0 {
                HStack {
                    Text("Tip total")
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                    Spacer()
                    Text(tipAmount, format: .currency(code: "CAD"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ChipInTheme.accent)
                }
            }

            if tipAmount > 0 || selectedPercent != nil {
                Button("Remove tip") {
                    selectedPercent = nil
                    customText = ""
                    tipAmount = 0
                }
                .font(.caption)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            }
        }
        .padding(14)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    }
}
