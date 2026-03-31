import SwiftUI

struct SettleUpView: View {
    let fromUserId: UUID
    let toUser: AppUser
    let amount: Decimal
    let groupId: UUID?

    @Environment(\.dismiss) var dismiss
    @State private var vm = SettleUpViewModel()
    @State private var showBankPicker = false
    @State private var amountCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isSettled {
                    VStack(spacing: 24) {
                        ConfettiView()
                        Text("🎉").font(.system(size: 72))
                        Text("All settled!")
                            .font(.title).bold().foregroundStyle(ChipInTheme.label)
                        Text("You sent \(amount, format: .currency(code: "CAD")) to \(toUser.name)")
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                            .multilineTextAlignment(.center)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(ChipInTheme.accent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 6) {
                            Text("You owe \(toUser.name)")
                                .font(.headline).foregroundStyle(ChipInTheme.secondaryLabel)
                            Text(amount, format: .currency(code: "CAD"))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(ChipInTheme.danger)
                        }

                        if let interac = toUser.interacContact {
                            HStack {
                                Image(systemName: "envelope.fill").foregroundStyle(ChipInTheme.secondaryLabel)
                                Text(interac).foregroundStyle(ChipInTheme.label)
                            }
                            .padding(12)
                            .background(ChipInTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(spacing: 12) {
                            Button {
                                vm.copyAmount(amount)
                                amountCopied = true
                            } label: {
                                Label(amountCopied ? "Copied!" : "Copy Amount",
                                      systemImage: amountCopied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ChipInTheme.elevated)
                                    .foregroundStyle(ChipInTheme.label)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button { showBankPicker = true } label: {
                                Label("Open Bank App", systemImage: "building.columns.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ChipInTheme.accent)
                                    .foregroundStyle(.black)
                                    .fontWeight(.semibold)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                Task {
                                    await vm.markAsSettled(
                                        fromUserId: fromUserId,
                                        toUserId: toUser.id,
                                        amount: amount,
                                        groupId: groupId
                                    )
                                }
                            } label: {
                                Text("I've sent it — mark as settled")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ChipInTheme.card)
                                    .foregroundStyle(ChipInTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Settle Up")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showBankPicker) {
                BankPickerSheet { bank in
                    vm.openBank(bank)
                    showBankPicker = false
                }
            }
        }
    }
}

struct BankPickerSheet: View {
    let onSelect: (BankApp) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(BankApp.allCases) { bank in
                Button(bank.rawValue) {
                    onSelect(bank)
                    dismiss()
                }
                .foregroundStyle(ChipInTheme.label)
                .listRowBackground(ChipInTheme.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ChipInTheme.background)
            .navigationTitle("Open Bank App")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
