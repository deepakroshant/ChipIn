import SwiftUI

struct QuickAddView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var coMembers: [AppUser] = []
    @State private var searchQuery = ""
    @State private var searchResults: [AppUser] = []
    @State private var isSearching = false
    @State private var selectedUserId: UUID?
    @State private var isSubmitting = false
    @State private var error: String?
    @FocusState private var amountFocused: Bool
    @FocusState private var searchFocused: Bool
    private let groupService = GroupService()
    private let expenseService = ExpenseService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Who pays you back?")
                            .font(.caption.uppercaseSmallCaps())
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                            .padding(.horizontal)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                            TextField("Name, @username, or email", text: $searchQuery)
                                .focused($searchFocused)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(ChipInTheme.label)
                                .onChange(of: searchQuery) { _, _ in
                                    Task { await runSearch() }
                                }
                            if isSearching {
                                ProgressView().tint(ChipInTheme.accent).scaleEffect(0.85)
                            } else if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                    searchResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                                }
                            }
                        }
                        .padding(12)
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)

                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Search results")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ChipInTheme.onSurfaceVariant)
                                    .padding(.horizontal)
                                    .padding(.bottom, 6)
                                ForEach(searchResults) { user in
                                    searchResultRow(user)
                                }
                            }
                        }

                        if !coMembers.isEmpty {
                            Text("From your groups")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ChipInTheme.onSurfaceVariant)
                                .padding(.horizontal)
                                .padding(.top, searchResults.isEmpty ? 0 : 8)

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

                    if coMembers.isEmpty, searchQuery.count < 2, searchResults.isEmpty {
                        Text("Search any ChipIn user for a direct 1:1 split. People from your groups also appear as shortcuts when you’re in groups.")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.danger)
                            .padding(.horizontal)
                    }

                    Spacer()

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
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadGroupShortcuts() }
            .onAppear { amountFocused = true }
        }
    }

    @ViewBuilder
    private var splitButtonLabel: some View {
        if isSubmitting {
            ProgressView().tint(ChipInTheme.onPrimary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            Text("Split It  ⚡️")
                .font(.headline)
                .foregroundStyle(ChipInTheme.onPrimary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    @ViewBuilder
    private func searchResultRow(_ user: AppUser) -> some View {
        let selected = selectedUserId == user.id
        Button {
            selectedUserId = user.id
            searchFocused = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(ChipInTheme.avatarColor(for: user.id.uuidString))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChipInTheme.label)
                    Text(user.handle)
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ChipInTheme.accent)
                }
            }
            .padding(12)
            .background(selected ? ChipInTheme.elevated : ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func personChip(user: AppUser) -> some View {
        let selected = selectedUserId == user.id
        let dname = user.displayName
        let colorKey = user.id.uuidString
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        selected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [ChipInTheme.avatarColor(for: colorKey), ChipInTheme.avatarColor(for: colorKey).opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(ChipInTheme.card)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle().stroke(selected ? ChipInTheme.accent : Color.clear, lineWidth: 2)
                    )
                Text(String(dname.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(selected ? .white : ChipInTheme.secondaryLabel)
            }
            .scaleEffect(selected ? 1.08 : 1.0)
            .animation(ChipInTheme.spring, value: selected)

            Text(dname.components(separatedBy: " ").first ?? dname)
                .font(.caption2)
                .foregroundStyle(selected ? ChipInTheme.accent : ChipInTheme.tertiaryLabel)
        }
        .onTapGesture {
            selectedUserId = user.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func loadGroupShortcuts() async {
        guard let id = auth.currentUser?.id else { return }
        coMembers = (try? await groupService.fetchCoMembers(excludingSelf: id)) ?? []
    }

    private func runSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        var found = (try? await groupService.searchUsers(trimmed)) ?? []
        if let me = auth.currentUser?.id {
            found.removeAll { $0.id == me }
        }
        searchResults = found
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
            ToastManager.shared.markLocalSave()
            NotificationCenter.default.post(
                name: .chipInToast,
                object: nil,
                userInfo: ["message": "Expense saved"]
            )
            SoundService.shared.play(.expenseAdd, haptic: .light)
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
