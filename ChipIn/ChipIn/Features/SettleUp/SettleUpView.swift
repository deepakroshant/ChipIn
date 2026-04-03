import SwiftUI

struct SettleUpView: View {
    let fromUserId: UUID
    let toUser: AppUser
    let amount: Decimal
    let groupId: UUID?
    /// true = I owe them (I'm paying). false = they owe me (I'm requesting).
    var isPayment: Bool = true

    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) var auth
    @State private var vm = SettleUpViewModel()
    @State private var showBankPicker = false
    @State private var amountCopied = false
    @State private var emailCopied = false
    private let service = SettlementService()

    private var myName: String { auth.currentUser?.name ?? "Me" }
    private var theirEmail: String { toUser.interacContact ?? toUser.email }

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isSettled {
                    settledState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            amountHeader
                            interacSection
                            bankSection
                            markSettledButton
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle(isPayment ? "Pay \(toUser.name)" : "Request from \(toUser.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .sheet(isPresented: $showBankPicker) {
                BankPickerSheet { bank in
                    vm.openBank(bank)
                    showBankPicker = false
                }
            }
        }
    }

    // MARK: - Sub-views

    private var amountHeader: some View {
        VStack(spacing: 8) {
            // Recipient avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [ChipInTheme.avatarColor(for: toUser.name), ChipInTheme.avatarColor(for: toUser.name).opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Text(String(toUser.name.prefix(1)).uppercased())
                    .font(.title.bold()).foregroundStyle(.white)
            }

            Text(toUser.name)
                .font(.headline).foregroundStyle(ChipInTheme.label)

            Text(amount, format: .currency(code: "CAD"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(isPayment ? ChipInTheme.danger : ChipInTheme.success)

            Text(isPayment ? "you owe" : "owes you")
                .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private var interacSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Interac e-Transfer", systemImage: "arrow.left.arrow.right.circle.fill")
                .font(.footnote.uppercaseSmallCaps())
                .foregroundStyle(ChipInTheme.tertiaryLabel)

            // Recipient email / phone chip
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(ChipInTheme.accent)
                Text(theirEmail)
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.label)
                    .lineLimit(1)
                Spacer()
                Button {
                    UIPasteboard.general.string = theirEmail
                    emailCopied = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { emailCopied = false }
                } label: {
                    Text(emailCopied ? "Copied!" : "Copy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(emailCopied ? ChipInTheme.success : ChipInTheme.accent)
                }
            }
            .padding(14)
            .background(ChipInTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Open in Mail (mailto: — no URL scheme declaration needed)
            Button {
                service.openInteracEmail(
                    to: theirEmail,
                    amount: amount,
                    recipientName: toUser.name,
                    senderName: myName,
                    isRequest: !isPayment
                )
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack {
                    Image(systemName: isPayment ? "paperplane.fill" : "tray.and.arrow.down.fill")
                    Text(isPayment ? "Open Mail — Send Interac" : "Open Mail — Request Interac")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ChipInTheme.accentGradient)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
            }

            Text("Opens your Mail app with the amount and recipient pre-filled. Send the email — your bank will notify them to complete the transfer.")
                .font(.caption)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
        }
        .padding(16)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private var bankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Open Banking App", systemImage: "building.columns.fill")
                .font(.footnote.uppercaseSmallCaps())
                .foregroundStyle(ChipInTheme.tertiaryLabel)

            Button { showBankPicker = true } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Choose Your Bank")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ChipInTheme.elevated)
                .foregroundStyle(ChipInTheme.label)
                .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
            }
        }
        .padding(16)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private var markSettledButton: some View {
        VStack(spacing: 8) {
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
                HStack {
                    if vm.isLoading {
                        ProgressView().tint(ChipInTheme.accent)
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text(isPayment ? "I've paid — mark as settled" : "They've paid — mark as settled")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ChipInTheme.card)
                .foregroundStyle(ChipInTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
            }
            .disabled(vm.isLoading)

            Text("Only mark as settled once payment is confirmed.")
                .font(.caption2)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
        }
    }

    private var settledState: some View {
        VStack(spacing: 24) {
            ConfettiView()
            Text("🎉").font(.system(size: 72))
            Text("All settled!")
                .font(.title.bold()).foregroundStyle(ChipInTheme.label)
            Text(isPayment
                ? "You paid \(amount, format: .currency(code: "CAD")) to \(toUser.name)"
                : "\(toUser.name) paid \(amount, format: .currency(code: "CAD")) back to you"
            )
            .foregroundStyle(ChipInTheme.secondaryLabel)
            .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(ChipInTheme.accent)
        }
        .padding()
    }
}

struct BankPickerSheet: View {
    let onSelect: (BankApp) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(BankApp.allCases) { bank in
                Button {
                    onSelect(bank)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(bank.emoji).font(.title2)
                        Text(bank.rawValue)
                            .foregroundStyle(ChipInTheme.label)
                    }
                }
                .listRowBackground(ChipInTheme.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ChipInTheme.background)
            .navigationTitle("Choose Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
}
