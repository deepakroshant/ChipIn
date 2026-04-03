import SwiftUI

struct AddExpenseView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var vm = AddExpenseViewModel()
    @State private var groups: [Group] = []
    @State private var groupMembers: [AppUser] = []
    @State private var coMembers: [AppUser] = []
    @State private var searchText = ""
    @State private var searchResults: [AppUser] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showItemSplit = false
    @FocusState private var amountFocused: Bool
    @FocusState private var searchFocused: Bool
    private let service = GroupService()

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
                        errorBanner
                    }
                    .padding()
                    .padding(.bottom, 40)
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
                    if vm.isSubmitting {
                        ProgressView().tint(ChipInTheme.accent)
                    } else {
                        Button("Save") {
                            Task {
                                if let id = auth.currentUser?.id, await vm.submit(paidBy: id) {
                                    dismiss()
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(ChipInTheme.accent)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        amountFocused = false
                        searchFocused = false
                    }
                    .foregroundStyle(ChipInTheme.accent)
                }
            }
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadInitialData() }
            .onChange(of: vm.context) { _, _ in Task { await reloadSplitPool() } }
            .onChange(of: vm.selectedGroupId) { _, _ in Task { await reloadSplitPool() } }
            .onChange(of: searchText) { _, newVal in
                Task { await performSearch(newVal) }
            }
            .sheet(isPresented: $vm.showReceiptScanner) {
                ReceiptScannerView(parsedReceipt: $vm.parsedReceipt)
            }
            .onChange(of: vm.parsedReceipt) { _, receipt in
                guard receipt != nil else { return }
                if vm.amount.isEmpty || vm.amount == "0.00" {
                    vm.amount = "\(vm.parsedReceipt?.total ?? 0)"
                }
                if vm.title.isEmpty { vm.title = "Receipt" }
                showItemSplit = true
            }
            .sheet(isPresented: $showItemSplit) {
                itemSplitSheet
            }
        }
    }

    @ViewBuilder
    private var itemSplitSheet: some View {
        let members = vm.context == .group ? groupMembers : coMembers
        let empty = ParsedReceipt(items: [], subtotal: 0, tax: 0, tip: 0, total: 0)
        ItemSplitView(
            receipt: Binding(
                get: { vm.parsedReceipt ?? empty },
                set: { vm.parsedReceipt = $0 }
            ),
            groupMembers: members
        )
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = vm.error {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Context picker

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
            Text(vm.context == .friends
                ? "Split with specific people. Balances update on Home."
                : "Expense belongs to one group.")
            .font(.caption)
            .foregroundStyle(ChipInTheme.tertiaryLabel)
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Amount")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Currency").foregroundStyle(ChipInTheme.secondaryLabel)
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
                TextField("0.00", text: $vm.amount)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(vm.amount.isEmpty ? ChipInTheme.tertiaryLabel : ChipInTheme.accent)
            }
            .padding(16)
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture { amountFocused = true }
        }
    }

    // MARK: - Details

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

    // MARK: - Split with (main change: live search)

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Split with")

            if vm.context == .friends {
                // Search box
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                        TextField("Name, @username or email", text: $searchText)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(ChipInTheme.label)
                        if isSearching {
                            ProgressView().tint(ChipInTheme.accent).scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                            }
                        }
                    }
                    .padding(12)
                    .background(ChipInTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Search results dropdown
                    if !searchResults.isEmpty && searchFocused {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { user in
                                let alreadyAdded = coMembers.contains(where: { $0.id == user.id })
                                Button {
                                    addPersonToSplit(user)
                                    searchText = ""
                                    searchFocused = false
                                } label: {
                                    HStack(spacing: 12) {
                                        avatarCircle(name: user.name, size: 36)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(user.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(ChipInTheme.label)
                                            Text(user.handle)
                                                .font(.caption)
                                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                                        }
                                        Spacer()
                                        if alreadyAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(ChipInTheme.success)
                                        } else {
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(ChipInTheme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if user.id != searchResults.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                        if let err = searchError {
                            Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
                        }
                    } else if searchText.count >= 2 && searchResults.isEmpty && !isSearching {
                        Text("No ChipIn users found for \"\(searchText)\"")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                            .padding(.top, 6)
                    }
                }
            }

            // Selected people list
            let list = vm.context == .friends ? coMembers : groupMembers
            if list.isEmpty && vm.context == .group {
                Text("Select a group first.")
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if !list.isEmpty {
                VStack(spacing: 0) {
                    ForEach(list) { user in
                        personRow(user: user)
                        if user.id != list.last?.id {
                            Divider().background(ChipInTheme.elevated).padding(.leading, 58)
                        }
                    }
                }
                .background(ChipInTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private func personRow(user: AppUser) -> some View {
        let isSelected = vm.selectedUserIds.contains(user.id)
        let isYou = user.id == auth.currentUser?.id
        Button {
            vm.toggleSplitParticipant(user.id)
        } label: {
            HStack(spacing: 12) {
                avatarCircle(name: user.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ChipInTheme.label)
                    Text(isYou ? "You" : user.handle)
                        .font(.caption)
                        .foregroundStyle(isYou ? ChipInTheme.accent : ChipInTheme.tertiaryLabel)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ChipInTheme.accent)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarCircle(name: String, size: CGFloat) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .bold))
            .frame(width: size, height: size)
            .background(ChipInTheme.avatarColor(for: name).opacity(0.3))
            .foregroundStyle(ChipInTheme.avatarColor(for: name))
            .clipShape(Circle())
    }

    // MARK: - Split type

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Split method")
            SplitPickerView(splitType: $vm.splitType)
                .padding(12)
                .background(ChipInTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Receipt

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Receipt")
            Button { vm.showReceiptScanner = true } label: {
                Label("Scan Receipt", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .foregroundStyle(ChipInTheme.accent)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Recurring

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

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ChipInTheme.secondaryLabel)
    }

    private func addPersonToSplit(_ user: AppUser) {
        if !coMembers.contains(where: { $0.id == user.id }) {
            coMembers.append(user)
        }
        if !vm.selectedUserIds.contains(user.id) {
            vm.selectedUserIds.append(user.id)
        }
    }

    private func performSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            searchResults = try await service.searchUsers(trimmed)
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
    }

    private func loadInitialData() async {
        guard let id = auth.currentUser?.id else { return }
        groups = (try? await service.fetchGroups(for: id)) ?? []
        coMembers = (try? await service.fetchCoMembers(excludingSelf: id)) ?? []
        if let selfUser = auth.currentUser {
            if !coMembers.contains(where: { $0.id == selfUser.id }) {
                coMembers.insert(selfUser, at: 0)
            }
        }
        vm.ensurePayerSelected(id)
        await reloadSplitPool()
    }

    private func reloadSplitPool() async {
        guard let id = auth.currentUser?.id else { return }
        switch vm.context {
        case .friends:
            coMembers = (try? await service.fetchCoMembers(excludingSelf: id)) ?? []
            if let selfUser = auth.currentUser {
                if !coMembers.contains(where: { $0.id == selfUser.id }) {
                    coMembers.insert(selfUser, at: 0)
                }
            }
            vm.ensurePayerSelected(id)
        case .group:
            guard let gid = vm.selectedGroupId else {
                groupMembers = []
                vm.selectedUserIds = []
                return
            }
            let users = (try? await service.fetchMembers(for: gid)) ?? []
            groupMembers = users
            vm.selectedUserIds = users.map(\.id)
        }
    }
}
