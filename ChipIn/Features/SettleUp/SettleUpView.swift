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
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if vm.isSettled {
                    VStack(spacing: 24) {
                        ConfettiView()
                        Text("🎉").font(.system(size: 72))
                        Text("All settled!")
                            .font(.title).bold().foregroundStyle(.white)
                        Text("You sent \(amount, format: .currency(code: "CAD")) to \(toUser.name)")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "#F97316"))
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 6) {
                            Text("You owe \(toUser.name)")
                                .font(.headline).foregroundStyle(.secondary)
                            Text(amount, format: .currency(code: "CAD"))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#F87171"))
                        }

                        if let interac = toUser.interacContact {
                            HStack {
                                Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                                Text(interac).foregroundStyle(.white)
                            }
                            .padding(12)
                            .background(Color(hex: "#1C1C1E"))
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
                                    .background(Color(hex: "#2C2C2E"))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button { showBankPicker = true } label: {
                                Label("Open Bank App", systemImage: "building.columns.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#F97316"))
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
                                    .background(Color(hex: "#1C1C1E"))
                                    .foregroundStyle(Color(hex: "#F97316"))
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
                .foregroundStyle(.white)
                .listRowBackground(Color(hex: "#1C1C1E"))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Open Bank App")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
