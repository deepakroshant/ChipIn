import SwiftUI

struct QuickAddView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var coMembers: [AppUser] = []
    @State private var selectedUserId: UUID?
    @State private var isSubmitting = false
    @State private var error: String?
    @FocusState private var amountFocused: Bool
    private let groupService = GroupService()
    private let expenseService = ExpenseService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    // Big amount input
                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .focused($amountFocused)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(amount.isEmpty ? ChipInTheme.tertiaryLabel : ChipInTheme.accent)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal)

                        TextField("What's this for?", text: $title)
                            .font(.title3)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Person picker scroll
                    if coMembers.isEmpty {
                        Text("Add friends via Groups to quick-split")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Split with")
                                .font(.caption.uppercaseSmallCaps())
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(coMembers) { user in
                                        personChip(user: user)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.danger)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        splitButtonLabel
                    }
                    .background(
                        (amount.isEmpty || selectedUserId == nil)
                            ? AnyView(ChipInTheme.elevated)
                            : AnyView(ChipInTheme.accentGradient)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    .padding(.horizontal)
                    .disabled(amount.isEmpty || selectedUserId == nil || isSubmitting)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadMembers() }
            .onAppear { amountFocused = true }
        }
    }

    @ViewBuilder
    private var splitButtonLabel: some View {
        if isSubmitting {
            ProgressView().tint(.black)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            Text("Split It  ⚡️")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    @ViewBuilder
    private func personChip(user: AppUser) -> some View {
        let selected = selectedUserId == user.id
        let name = user.name
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        selected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [ChipInTheme.avatarColor(for: name), ChipInTheme.avatarColor(for: name).opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(ChipInTheme.card)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle().stroke(selected ? ChipInTheme.accent : Color.clear, lineWidth: 2)
                    )
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(selected ? .white : ChipInTheme.secondaryLabel)
            }
            .scaleEffect(selected ? 1.08 : 1.0)
            .animation(ChipInTheme.spring, value: selected)

            Text(name.components(separatedBy: " ").first ?? name)
                .font(.caption2)
                .foregroundStyle(selected ? ChipInTheme.accent : ChipInTheme.tertiaryLabel)
        }
        .onTapGesture {
            selectedUserId = user.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func loadMembers() async {
        guard let id = auth.currentUser?.id else { return }
        coMembers = (try? await groupService.fetchCoMembers(excludingSelf: id)) ?? []
    }

    private func save() async {
        guard let paidBy = auth.currentUser?.id,
              let otherId = selectedUserId,
              let amt = Decimal(string: amount), amt > 0 else {
            error = "Enter an amount and pick a person."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let expTitle = title.isEmpty ? "Quick split" : title
            let splits = expenseService.calculateEqualSplits(amount: amt, userIds: [paidBy, otherId])
            try await expenseService.createExpense(
                groupId: nil,
                paidBy: paidBy,
                title: expTitle,
                amount: amt,
                currency: "CAD",
                category: ExpenseCategory.other.rawValue,
                splitType: .equal,
                splits: splits,
                isRecurring: false,
                recurrenceInterval: nil
            )
            SoundService.shared.play(.expenseAdd, haptic: .light)
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
