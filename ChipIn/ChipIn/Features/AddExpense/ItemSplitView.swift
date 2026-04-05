import SwiftUI

struct ItemSplitView: View {
    @Binding var receipt: ParsedReceipt
    let groupMembers: [AppUser]
    let currentUserId: UUID?
    @Environment(\.dismiss) var dismiss

    private var unassignedItems: [Int] {
        receipt.items.indices.filter { receipt.items[$0].assignedTo == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if !unassignedItems.isEmpty && !groupMembers.isEmpty {
                    Section {
                        Button("Split \(unassignedItems.count) unassigned equally") {
                            for (offset, idx) in unassignedItems.enumerated() {
                                receipt.items[idx].assignedTo = groupMembers[offset % groupMembers.count].id
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.accent)
                        .listRowBackground(ChipInTheme.card)
                    }
                }

                Section("Items — assign each to one person") {
                    ForEach(receipt.items.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(receipt.items[idx].name.prefix(40)))
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
                                    Text(member.displayName).tag(Optional(member.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ChipInTheme.accent)
                        }
                        .listRowBackground(ChipInTheme.card)
                    }
                }

                Section("Per Person") {
                    ForEach(groupMembers) { member in
                        let total = receipt.items
                            .filter { $0.assignedTo == member.id }
                            .reduce(Decimal(0)) { $0 + $1.price + $1.taxPortion }
                        if total > 0 {
                            HStack {
                                Text(member.displayName)
                                    .foregroundStyle(ChipInTheme.label)
                                Spacer()
                                Text(total, format: .currency(code: "CAD"))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ChipInTheme.accent)
                            }
                            .listRowBackground(ChipInTheme.card)
                        }
                    }
                    let unassignedTotal = receipt.items
                        .filter { $0.assignedTo == nil }
                        .reduce(Decimal(0)) { $0 + $1.price + $1.taxPortion }
                    if unassignedTotal > 0 {
                        HStack {
                            Text("Unassigned").foregroundStyle(ChipInTheme.secondaryLabel)
                            Spacer()
                            Text(unassignedTotal, format: .currency(code: "CAD"))
                                .foregroundStyle(ChipInTheme.danger)
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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let myId = currentUserId {
                            Button("Assign all to me") {
                                for i in receipt.items.indices {
                                    receipt.items[i].assignedTo = myId
                                }
                            }
                        }
                        Button("Clear all assignments") {
                            for i in receipt.items.indices {
                                receipt.items[i].assignedTo = nil
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(ChipInTheme.accent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ChipInTheme.accent)
                }
            }
        }
    }
}
