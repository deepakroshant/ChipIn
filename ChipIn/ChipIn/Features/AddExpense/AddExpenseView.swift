import SwiftUI

struct AddExpenseView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var vm = AddExpenseViewModel()
    @State private var groups: [Group] = []
    @State private var groupMembers: [AppUser] = []
    @State private var coMembers: [AppUser] = []
    @State private var emailLookupError: String?
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        contextPicker
                        amountSection
                        detailsSection
                        splitWithSection
                        splitTypeSection
                        receiptSection
                        recurringSection
                        if let error = vm.error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(ChipInTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
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
                    .fontWeight(.semibold)
                    .foregroundStyle(ChipInTheme.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                        .foregroundStyle(ChipInTheme.accent)
                }
            }
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadInitialData()
            }
            .onChange(of: vm.context) { _, _ in
                Task { await reloadSplitPool() }
            }
            .onChange(of: vm.selectedGroupId) { _, _ in
                Task { await reloadSplitPool() }
            }
            .sheet(isPresented: $vm.showReceiptScanner) {
                ReceiptScannerView(parsedReceipt: $vm.parsedReceipt)
            }
        }
    }

    private var contextPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ChipInTheme.secondaryLabel)
            Picker("Context", selection: $vm.context) {
                ForEach(AddExpenseContext.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.segmented)
            Text(
                vm.context == .friends
                    ? "Split with specific people. Your running balance updates on Home. Group trips stay under the Groups tab."
                    : "Expense belongs to one group; split among members you choose."
            )
            .font(.caption)
            .foregroundStyle(ChipInTheme.tertiaryLabel)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Amount")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Currency")
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                    Spacer()
                    Picker("Currency", selection: $vm.currency) {
                        Text("CAD").tag("CAD")
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }
                    .pickerStyle(.menu)
                    .tint(ChipInTheme.accent)
                }
                HStack(alignment: .firstTextBaseline) {
                    TextField("0.00", text: $vm.amount)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ChipInTheme.accent)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Details")
            VStack(spacing: 0) {
                TextField("What's this for?", text: $vm.title)
                    .foregroundStyle(ChipInTheme.label)
                    .padding(16)
                Divider().background(ChipInTheme.elevated)
                if vm.context == .group {
                    Picker("Group", selection: $vm.selectedGroupId) {
                        Text("Select group").tag(Optional<UUID>.none)
                        ForEach(groups) { g in
                            Text("\(g.emoji) \(g.name)").tag(Optional(g.id))
                        }
                    }
                    .padding(16)
                    .tint(ChipInTheme.accent)
                    .foregroundStyle(ChipInTheme.label)
                    Divider().background(ChipInTheme.elevated)
                }
                Picker("Category", selection: $vm.category) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                    }
                }
                .padding(16)
                .tint(ChipInTheme.accent)
                .foregroundStyle(ChipInTheme.label)
            }
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Split with")
            Text(
                vm.context == .friends
                    ? "Tap people below. Add someone by email if they already use ChipIn."
                    : "Choose who is part of this split (group expense)."
            )
            .font(.caption)
            .foregroundStyle(ChipInTheme.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)

            if vm.context == .friends {
                emailInviteRow
            }

            if vm.context == .friends && coMembers.isEmpty && auth.currentUser != nil {
                Text("No one from your groups yet — add a friend’s account email below.")
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                    .padding(.bottom, 4)
            }

            if splitParticipantList.isEmpty {
                Text(vm.context == .group ? "Select a group first." : "Add people above.")
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(splitParticipantList) { user in
                        splitRow(user: user)
                        if user.id != splitParticipantList.last?.id {
                            Divider().background(ChipInTheme.elevated)
                        }
                    }
                }
                .background(ChipInTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var emailInviteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Friend’s email (ChipIn account)", text: $vm.friendEmailLookup)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .foregroundStyle(ChipInTheme.label)
                    .padding(12)
                    .background(ChipInTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button("Add") {
                    Task { await lookupEmail() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(ChipInTheme.accent)
                .disabled(vm.friendEmailLookup.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let err = emailLookupError {
                Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
            }
        }
        .padding(.bottom, 4)
    }

    private var splitParticipantList: [AppUser] {
        vm.context == .friends ? coMembers : groupMembers
    }

    @ViewBuilder
    private func splitRow(user: AppUser) -> some View {
        Button {
            vm.toggleSplitParticipant(user.id)
        } label: {
            HStack(spacing: 12) {
                Text(nameInitials(user.name))
                    .font(.caption.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(ChipInTheme.elevated)
                    .foregroundStyle(ChipInTheme.label)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .foregroundStyle(ChipInTheme.label)
                    if user.id == auth.currentUser?.id {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(ChipInTheme.accent)
                    }
                }
                Spacer()
                Image(systemName: vm.selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        vm.selectedUserIds.contains(user.id) ? ChipInTheme.accent : ChipInTheme.tertiaryLabel
                    )
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Split method")
            SplitPickerView(splitType: $vm.splitType)
                .padding(12)
                .background(ChipInTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Receipt")
            Button {
                vm.showReceiptScanner = true
            } label: {
                Label("Scan Receipt", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .foregroundStyle(ChipInTheme.accent)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recurring")
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Repeat automatically", isOn: $vm.isRecurring)
                    .tint(ChipInTheme.accent)
                    .foregroundStyle(ChipInTheme.label)
                if vm.isRecurring {
                    Picker("Frequency", selection: $vm.recurrenceInterval) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Bi-weekly").tag("biweekly")
                        Text("Monthly").tag("monthly")
                    }
                    .tint(ChipInTheme.accent)
                }
            }
            .padding(16)
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ChipInTheme.secondaryLabel)
    }

    private func nameInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private func loadInitialData() async {
        guard let id = auth.currentUser?.id else { return }
        groups = (try? await GroupService().fetchGroups(for: id)) ?? []
        coMembers = (try? await GroupService().fetchCoMembers(excludingSelf: id)) ?? []
        if let selfUser = auth.currentUser {
            coMembers = mergeSelfUser(selfUser, into: coMembers)
        }
        vm.ensurePayerSelected(id)
        await reloadSplitPool()
    }

    private func mergeSelfUser(_ selfUser: AppUser, into users: [AppUser]) -> [AppUser] {
        var out = users
        if !out.contains(where: { $0.id == selfUser.id }) {
            out.insert(selfUser, at: 0)
        }
        return out
    }

    private func reloadSplitPool() async {
        emailLookupError = nil
        guard let id = auth.currentUser?.id else { return }
        switch vm.context {
        case .friends:
            coMembers = (try? await GroupService().fetchCoMembers(excludingSelf: id)) ?? []
            if let selfUser = auth.currentUser {
                coMembers = mergeSelfUser(selfUser, into: coMembers)
            }
            vm.ensurePayerSelected(id)
        case .group:
            guard let gid = vm.selectedGroupId else {
                groupMembers = []
                vm.selectedUserIds = []
                return
            }
            do {
                let users = try await GroupService().fetchMembers(for: gid)
                groupMembers = users
                vm.selectedUserIds = users.map(\.id)
            } catch {
                groupMembers = []
                vm.selectedUserIds = []
            }
        }
    }

    private func lookupEmail() async {
        emailLookupError = nil
        do {
            guard let found = try await GroupService().findUserByEmail(vm.friendEmailLookup) else {
                emailLookupError = "No ChipIn account for that email. They must sign up first."
                return
            }
            guard found.id != auth.currentUser?.id else {
                emailLookupError = "That’s you — already included."
                return
            }
            vm.addUserFromEmailLookup(found)
            if !coMembers.contains(where: { $0.id == found.id }) {
                coMembers.append(found)
            }
        } catch {
            emailLookupError = error.localizedDescription
        }
    }
}
