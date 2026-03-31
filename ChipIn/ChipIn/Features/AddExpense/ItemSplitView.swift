import SwiftUI

struct ItemSplitView: View {
    @Binding var receipt: ParsedReceipt
    let groupMembers: [AppUser]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Items — assign each to one person") {
                    ForEach(receipt.items.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(receipt.items[idx].name)
                                    .fontWeight(.medium)
                                    .foregroundStyle(ChipInTheme.label)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(receipt.items[idx].price, format: .currency(code: "CAD"))
                                        .foregroundStyle(ChipInTheme.accent)
                                    Text("+\(receipt.items[idx].taxPortion, format: .currency(code: "CAD")) tax")
                                        .font(.caption2)
                                        .foregroundStyle(ChipInTheme.secondaryLabel)
                                }
                            }

                            Picker("Assign to", selection: $receipt.items[idx].assignedTo) {
                                Text("Unassigned").tag(Optional<UUID>.none)
                                ForEach(groupMembers) { member in
                                    Text(member.name).tag(Optional(member.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ChipInTheme.accent)
                        }
                        .listRowBackground(ChipInTheme.card)
                    }
                }

                Section("Receipt Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(receipt.subtotal, format: .currency(code: "CAD"))
                    }
                    .listRowBackground(ChipInTheme.card)
                    .foregroundStyle(ChipInTheme.secondaryLabel)

                    HStack {
                        Text("Tax")
                        Spacer()
                        Text(receipt.tax, format: .currency(code: "CAD"))
                    }
                    .listRowBackground(ChipInTheme.card)
                    .foregroundStyle(ChipInTheme.secondaryLabel)

                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text(receipt.total, format: .currency(code: "CAD"))
                            .bold()
                            .foregroundStyle(ChipInTheme.accent)
                    }
                    .listRowBackground(ChipInTheme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ChipInTheme.background)
            .navigationTitle("Assign Items")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ChipInTheme.accent)
                }
            }
        }
    }
}
