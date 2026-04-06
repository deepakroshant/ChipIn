import SwiftUI
import StoreKit
import UIKit

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
    @State private var copiedField: String?
    @State private var preferredBank: BankApp?
    @AppStorage("settleCount") private var settleCount = 0
    private let service = SettlementService()

    private var theirEmail: String { toUser.interacContact ?? toUser.email }
    private var reference: String { "ChipIn payment" }
    private var tintColor: Color { isPayment ? ChipInTheme.success : ChipInTheme.accent }
    private var amountString: String { String(format: "$%.2f", NSDecimalNumber(decimal: amount).doubleValue) }

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isSettled {
                    settledState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            heroHeader
                            transferDetailsCard
                            bankSection
                            markSettledButton
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle(isPayment ? "Pay via Interac" : "Request via Interac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .sheet(isPresented: $showBankPicker) {
                BankPickerSheet { bank in
                    preferredBank = bank
                    saveBankPreference(bank)
                    showBankPicker = false
                    service.openBankApp(bank)
                }
            }
            .onAppear { loadBankPreference() }
            .onChange(of: vm.isSettled) { _, settled in
                guard settled else { return }
                settleCount += 1
                if settleCount == 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            if #available(iOS 18.0, *) {
                                AppStore.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var heroHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [ChipInTheme.avatarColor(for: toUser.id.uuidString), ChipInTheme.avatarColor(for: toUser.id.uuidString).opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Text(String(toUser.displayName.prefix(1)).uppercased())
                    .font(.title.bold()).foregroundStyle(.white)
            }

            Text(toUser.displayName)
                .font(.headline).foregroundStyle(ChipInTheme.label)

            Text(isPayment ? "You're sending" : "You're requesting")
                .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)

            Text(amount, format: .currency(code: "CAD"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(tintColor)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private var transferDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Transfer Details", systemImage: "arrow.left.arrow.right.circle.fill")
                .font(.footnote.uppercaseSmallCaps())
                .foregroundStyle(ChipInTheme.tertiaryLabel)

            detailRow(
                label: isPayment ? "Send to (Interac email)" : "Request from",
                value: theirEmail,
                field: "email"
            )
            Divider().background(ChipInTheme.elevated)
            detailRow(label: "Amount", value: amountString, field: "amount")
            Divider().background(ChipInTheme.elevated)
            detailRow(label: "Reference / Note", value: reference, field: "reference")
        }
        .padding(16)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private func detailRow(label: String, value: String, field: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.caption).foregroundStyle(ChipInTheme.tertiaryLabel)
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(ChipInTheme.label)
            }
            Spacer()
            copyButton(text: value, field: field)
        }
    }

    private func copyButton(text: String, field: String) -> some View {
        Button {
            UIPasteboard.general.string = text
            copiedField = field
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedField = nil }
        } label: {
            Text(copiedField == field ? "Copied!" : "Copy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(copiedField == field ? ChipInTheme.success : ChipInTheme.accent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(ChipInTheme.elevated)
                .clipShape(Capsule())
        }
    }

    private var bankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Open Banking App", systemImage: "building.columns.fill")
                .font(.footnote.uppercaseSmallCaps())
                .foregroundStyle(ChipInTheme.tertiaryLabel)

            if let bank = preferredBank {
                Button {
                    service.openBankApp(bank)
                } label: {
                    HStack {
                        Text(bank.emoji)
                        Text("Open \(bank.rawValue)")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tintColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                }

                Button { showBankPicker = true } label: {
                    Text("Choose a Different Bank")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button { showBankPicker = true } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app.fill")
                        Text("Open Your Bank App")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tintColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                }
            }

            Text("Copy the details above, open your bank app, and paste into the e-Transfer form.")
                .font(.caption)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
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
                        Text(isPayment ? "I've sent the transfer — Mark Settled" : "They've paid — Mark Settled")
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
                ? "You paid \(amount, format: .currency(code: "CAD")) to \(toUser.displayName)"
                : "\(toUser.displayName) paid \(amount, format: .currency(code: "CAD")) back to you"
            )
            .foregroundStyle(ChipInTheme.secondaryLabel)
            .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(ChipInTheme.accent)
        }
        .padding()
    }

    // MARK: - Bank Preference

    private func loadBankPreference() {
        if let name = UserDefaults.standard.string(forKey: "preferredBankName") {
            preferredBank = BankApp.allCases.first { $0.rawValue == name }
        }
    }

    private func saveBankPreference(_ bank: BankApp) {
        UserDefaults.standard.set(bank.rawValue, forKey: "preferredBankName")
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
                } label: {
                    HStack(spacing: 12) {
                        Text(bank.emoji).font(.title2)
                        Text(bank.rawValue)
                            .foregroundStyle(ChipInTheme.label)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
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
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
