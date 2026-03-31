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
                                    .foregroundStyle(.white)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(receipt.items[idx].price, format: .currency(code: "CAD"))
                                        .foregroundStyle(Color(hex: "#F97316"))
                                    Text("+\(receipt.items[idx].taxPortion, format: .currency(code: "CAD")) tax")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Picker("Assign to", selection: $receipt.items[idx].assignedTo) {
                                Text("Unassigned").tag(Optional<UUID>.none)
                                ForEach(groupMembers) { member in
                                    Text(member.name).tag(Optional(member.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color(hex: "#F97316"))
                        }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    }
                }

                Section("Receipt Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(receipt.subtotal, format: .currency(code: "CAD"))
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                    .foregroundStyle(.secondary)

                    HStack {
                        Text("Tax")
                        Spacer()
                        Text(receipt.tax, format: .currency(code: "CAD"))
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                    .foregroundStyle(.secondary)

                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text(receipt.total, format: .currency(code: "CAD"))
                            .bold()
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Assign Items")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#F97316"))
                }
            }
        }
    }
}
