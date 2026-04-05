import SwiftUI

struct AddExpenseView: View {
    let prefill: Expense?

    init(prefill: Expense? = nil) {
        self.prefill = prefill
    }

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
    /// Collapsed by default so simple expenses aren’t buried in split/receipt/tax controls.
    @State private var showMoreOptions = false
    @FocusState private var amountFocused: Bool
    @FocusState private var searchFocused: Bool
    private let service = GroupService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if let userId = auth.currentUser?.id, !vm.templates.isEmpty {
                            TemplatePickerView(
                                templates: vm.templates,
                                onSelect: { vm.applyTemplate($0) },
                                onDelete: { t in Task { await vm.deleteTemplate(t) } }
                            )
                        }
                        contextPicker
                        amountSection
                        detailsSection
                        splitWithSection
                        paidBySection
                        moreOptionsSection
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
                                guard let id = auth.currentUser?.id else { return }
                                if await vm.submit(defaultPaidBy: id) {
                                    vm.showSaveTemplatePrompt = true
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(ChipInTheme.accent)
                    }
                }
            }
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Save as Template?", isPresented: $vm.showSaveTemplatePrompt) {
                TextField("e.g. Tim Hortons Run", text: $vm.templateName)
                Button("Save") {
                    guard let id = auth.currentUser?.id, !vm.templateName.isEmpty else {
                        dismiss()
                        return
                    }
                    Task {
                        await vm.saveCurrentAsTemplate(userId: id, name: vm.templateName)
                        dismiss()
                    }
                }
                Button("Skip", role: .cancel) { dismiss() }
            } message: {
                Text("Reuse this setup for quick expense entry next time.")
            }
            .task {
                if let id = auth.currentUser?.id { await vm.loadTemplates(userId: id) }
                await loadInitialData()
                if let p = prefill {
                    vm.title = p.title + " (copy)"
                    vm.amount = "\(p.totalAmount)"
                    vm.currency = p.currency
                    if let cat = ExpenseCategory(rawValue: p.category) {
                        vm.category = cat
                    }
                }
            }
            .onChange(of: vm.context) { _, _ in Task { await reloadSplitPool() } }
            .onChange(of: vm.selectedGroupId) { _, _ in Task { await reloadSplitPool() } }
            .onChange(of: searchText) { _, newVal in
                Task { await performSearch(newVal) }
            }
            .sheet(isPresented: $vm.showReceiptScanner) {
                ReceiptScannerView(parsedReceipt: $vm.parsedReceipt)
            }
            .onChange(of: vm.parsedReceipt) { _, receipt in
                guard let receipt else { return }
                if !receipt.items.isEmpty {
                    vm.splitType = .byItem
                }
                showMoreOptions = true
                if vm.amount.isEmpty || vm.amount == "0.00" {
                    vm.amount = "\(vm.parsedReceipt?.total ?? 0)"
                }
                if vm.title.isEmpty { vm.title = "Receipt" }
                // Let the scanner sheet finish dismissing before presenting Assign Items (avoids stacked sheet glitches).
                if !receipt.items.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showItemSplit = true
                    }
                }
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
            groupMembers: members,
            currentUserId: auth.currentUser?.id
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

    /// Keeps the default path simple (amount + who); receipt scan & split modes live here.
    private var moreOptionsSection: some View {
        DisclosureGroup(isExpanded: $showMoreOptions) {
            VStack(spacing: 20) {
                taxSection
                if vm.category == .food || vm.category == .fun {
                    TipCalculatorView(subtotal: vm.amountDecimal, tipAmount: $vm.tipAmount)
                        .animation(.spring(response: 0.35), value: vm.category)
                }
                splitTypeSection
                customSplitSection
                receiptSection
                recurringSection
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax, split method & receipt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChipInTheme.label)
                    Text("Optional — scan a receipt, add tax, or change how you split.")
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .tint(ChipInTheme.accent)
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
            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
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
                    .onChange(of: vm.title) { _, newTitle in
                        vm.autoDetectCategory(from: newTitle)
                    }
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
                .onChange(of: vm.category) { _, _ in
                    vm.wasAutoDetected = false
                }
                if vm.wasAutoDetected {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.caption2)
                        Text("Auto-detected").font(.caption2)
                    }
                    .foregroundStyle(ChipInTheme.accent.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .scale(0.9)))
                    .animation(.easeInOut(duration: 0.2), value: vm.wasAutoDetected)
                }
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
                                        avatarCircle(user: user, size: 36)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(user.displayName)
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
                avatarCircle(user: user, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
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
    private func avatarCircle(user: AppUser, size: CGFloat) -> some View {
        let d = user.displayName
        Text(String(d.prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .bold))
            .frame(width: size, height: size)
            .background(ChipInTheme.avatarColor(for: user.id.uuidString).opacity(0.3))
            .foregroundStyle(ChipInTheme.avatarColor(for: user.id.uuidString))
            .clipShape(Circle())
    }

    // MARK: - Split type

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Split method")
            if let r = vm.parsedReceipt, !r.items.isEmpty {
                Text("This expense follows your receipt lines. Unassigned lines are split evenly across everyone selected.")
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                SplitPickerView(splitType: $vm.splitType)
                    .padding(12)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Tax

    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tax (optional)")
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                TextField("0.00", text: $vm.taxAmount)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(vm.taxAmount.isEmpty ? ChipInTheme.tertiaryLabel : ChipInTheme.label)
                if !vm.taxAmount.isEmpty {
                    Text("= \(vm.totalWithTax, format: .currency(code: vm.currency)) total")
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .padding(14)
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Paid by

    @ViewBuilder
    private var paidBySection: some View {
        let list = vm.context == .friends ? coMembers : groupMembers
        if list.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Paid by")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(list) { user in
                            let isSelected = (vm.paidByOverride ?? auth.currentUser?.id) == user.id
                            let isYou = user.id == auth.currentUser?.id
                            Button {
                                vm.paidByOverride = user.id
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(String(user.displayName.prefix(1)).uppercased())
                                        .font(.caption.bold())
                                        .frame(width: 26, height: 26)
                                        .background(ChipInTheme.avatarColor(for: user.id.uuidString).opacity(isSelected ? 1 : 0.3))
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                    Text(isYou ? "You" : user.displayName.components(separatedBy: " ").first ?? user.displayName)
                                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? ChipInTheme.label : ChipInTheme.secondaryLabel)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? ChipInTheme.elevated : ChipInTheme.card)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? ChipInTheme.accent : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Custom split inputs

    @ViewBuilder
    private var customSplitSection: some View {
        if vm.splitType != .equal && vm.splitType != .byItem && !vm.selectedUserIds.isEmpty {
            let list = vm.context == .friends ? coMembers : groupMembers
            let participants = list.filter { vm.selectedUserIds.contains($0.id) }
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle(splitSectionTitle)
                    VStack(spacing: 0) {
                        ForEach(participants) { user in
                            customSplitRow(user: user)
                            if user.id != participants.last?.id {
                                Divider().background(ChipInTheme.elevated).padding(.leading, 14)
                            }
                        }
                        // Summary row
                        Divider().background(ChipInTheme.elevated)
                        HStack {
                            Text(splitSummaryLabel)
                                .font(.caption)
                                .foregroundStyle(splitSummaryOk ? ChipInTheme.success : ChipInTheme.danger)
                            Spacer()
                            Text(splitSummaryValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(splitSummaryOk ? ChipInTheme.success : ChipInTheme.danger)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    @ViewBuilder
    private func customSplitRow(user: AppUser) -> some View {
        let isYou = user.id == auth.currentUser?.id
        HStack(spacing: 12) {
            avatarCircle(user: user, size: 36)
            Text(isYou ? "You" : user.displayName.components(separatedBy: " ").first ?? user.displayName)
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.label)
            Spacer()
            HStack(spacing: 4) {
                Text(splitInputPrefix).foregroundStyle(ChipInTheme.tertiaryLabel).font(.subheadline)
                TextField(splitInputPlaceholder, text: Binding(
                    get: { vm.customSplitValues[user.id] ?? "" },
                    set: { vm.customSplitValues[user.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .foregroundStyle(ChipInTheme.label)
                Text(splitInputSuffix).foregroundStyle(ChipInTheme.tertiaryLabel).font(.subheadline)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var splitSectionTitle: String {
        switch vm.splitType {
        case .percent: return "Percentages (must total 100%)"
        case .exact:   return "Exact amounts (must total \(vm.currency) \(vm.totalWithTax))"
        case .shares:  return "Shares (any ratio, e.g. 2 : 1)"
        default:       return "Split breakdown"
        }
    }

    private var splitInputPrefix: String {
        switch vm.splitType {
        case .exact: return "$"
        default:     return ""
        }
    }
    private var splitInputSuffix: String {
        switch vm.splitType {
        case .percent: return "%"
        default:       return ""
        }
    }
    private var splitInputPlaceholder: String {
        switch vm.splitType {
        case .percent: return "50"
        case .exact:   return "0.00"
        case .shares:  return "1"
        default:       return ""
        }
    }

    private var splitSummaryOk: Bool {
        switch vm.splitType {
        case .percent: return abs(vm.percentTotal - 100) <= 0.01
        case .exact:   return abs(vm.exactTotal - vm.totalWithTax) <= 0.01
        case .shares:  return vm.sharesTotal > 0
        default:       return true
        }
    }
    private var splitSummaryLabel: String {
        switch vm.splitType {
        case .percent: return splitSummaryOk ? "✓ Adds up to 100%" : "Must reach 100%"
        case .exact:   return splitSummaryOk ? "✓ Balanced" : "Remaining"
        case .shares:  return splitSummaryOk ? "✓ Ratio set" : "Enter at least one share"
        default:       return ""
        }
    }
    private var splitSummaryValue: String {
        switch vm.splitType {
        case .percent: return "\(vm.percentTotal)%"
        case .exact:
            let rem = vm.totalWithTax - vm.exactTotal
            if splitSummaryOk { return "All good" }
            return rem >= 0 ? "-\(rem)" : "+\(abs(rem))"
        case .shares:  return "\(vm.sharesTotal) shares"
        default:       return ""
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
