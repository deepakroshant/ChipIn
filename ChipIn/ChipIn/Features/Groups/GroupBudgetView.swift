import SwiftUI
import Supabase

struct GroupBudgetView: View {
    let group: Group
    let totalSpent: Decimal
    @State private var budgetInput = ""
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss

    private var budget: Decimal { Decimal(string: budgetInput) ?? group.budget ?? 0 }
    private var pctUsed: Double {
        guard budget > 0 else { return 0 }
        return min(1.0, NSDecimalNumber(decimal: totalSpent / budget).doubleValue)
    }
    private var remaining: Decimal { max(0, budget - totalSpent) }
    private var overBudget: Bool { totalSpent > budget && budget > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(ChipInTheme.elevated, lineWidth: 16)
                            .frame(width: 180, height: 180)
                        Circle()
                            .trim(from: 0, to: pctUsed)
                            .stroke(
                                overBudget ? ChipInTheme.danger : ChipInTheme.accent,
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(ChipInTheme.spring, value: pctUsed)
                        VStack(spacing: 4) {
                            Text("\(Int(pctUsed * 100))%")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(overBudget ? ChipInTheme.danger : ChipInTheme.label)
                            Text(overBudget ? "Over budget!" : "used")
                                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                    }
                    .padding(.top)

                    HStack(spacing: 0) {
                        statCell(label: "Spent", value: totalSpent, color: ChipInTheme.danger)
                        Divider().frame(height: 40)
                        statCell(label: "Budget", value: budget, color: ChipInTheme.label)
                        Divider().frame(height: 40)
                        statCell(label: "Left", value: remaining, color: ChipInTheme.success)
                    }
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Budget").font(.caption.uppercaseSmallCaps()).foregroundStyle(ChipInTheme.tertiaryLabel)
                        HStack {
                            Text("$").foregroundStyle(ChipInTheme.tertiaryLabel)
                            TextField(group.budget != nil ? "\(group.budget!)" : "0.00", text: $budgetInput)
                                .keyboardType(.decimalPad)
                                .foregroundStyle(ChipInTheme.label)
                        }
                        .padding(14).background(ChipInTheme.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Button {
                        Task { await saveBudget() }
                    } label: {
                        Text(isSaving ? "Saving…" : "Save Budget")
                            .frame(maxWidth: .infinity).padding()
                            .background(ChipInTheme.accentGradient)
                            .foregroundStyle(.black).fontWeight(.semibold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(isSaving || budgetInput.isEmpty)
                    Spacer()
                }
            }
            .navigationTitle("Group Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func statCell(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .currency(code: "CAD"))
                .font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(ChipInTheme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func saveBudget() async {
        guard let amt = Decimal(string: budgetInput) else { return }
        isSaving = true
        defer { isSaving = false }
        try? await supabase
            .from("groups")
            .update(["budget": "\(amt)"])
            .eq("id", value: group.id.uuidString)
            .execute()
        dismiss()
    }
}
