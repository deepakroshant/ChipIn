import SwiftUI

struct AddExpenseView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var vm = AddExpenseViewModel()
    @State private var groups: [Group] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Picker("Currency", selection: $vm.currency) {
                            Text("CAD").tag("CAD")
                            Text("USD").tag("USD")
                            Text("EUR").tag("EUR")
                            Text("GBP").tag("GBP")
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        TextField("0.00", text: $vm.amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }

                Section("Details") {
                    TextField("What's this for?", text: $vm.title)
                    Picker("Group", selection: $vm.selectedGroupId) {
                        Text("Select group").tag(Optional<UUID>.none)
                        ForEach(groups) { g in
                            Text("\(g.emoji) \(g.name)").tag(Optional(g.id))
                        }
                    }
                    Picker("Category", selection: $vm.category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                }

                Section("Split") {
                    SplitPickerView(splitType: $vm.splitType)
                }

                Section("Receipt") {
                    Button {
                        vm.showReceiptScanner = true
                    } label: {
                        Label("Scan Receipt", systemImage: "camera.fill")
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }

                Section("Recurring") {
                    Toggle("Repeat automatically", isOn: $vm.isRecurring)
                        .tint(Color(hex: "#F97316"))
                    if vm.isRecurring {
                        Picker("Frequency", selection: $vm.recurrenceInterval) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                            Text("Bi-weekly").tag("biweekly")
                            Text("Monthly").tag("monthly")
                        }
                    }
                }

                if let error = vm.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let id = auth.currentUser?.id, await vm.submit(paidBy: id) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isSubmitting)
                }
            }
            .task {
                if let id = auth.currentUser?.id {
                    groups = (try? await GroupService().fetchGroups(for: id)) ?? []
                }
            }
            .sheet(isPresented: $vm.showReceiptScanner) {
                ReceiptScannerView(parsedReceipt: $vm.parsedReceipt)
            }
        }
    }
}
