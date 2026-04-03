import SwiftUI
import Supabase

struct SearchView: View {
    @Environment(AuthManager.self) var auth
    @State private var query = ""
    @State private var results: [Expense] = []
    @State private var isSearching = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(ChipInTheme.tertiaryLabel)
                        TextField("Search expenses…", text: $query)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .foregroundStyle(ChipInTheme.label)
                            .onChange(of: query) { _, val in Task { await search(val) } }
                        if isSearching {
                            ProgressView().tint(ChipInTheme.accent).scaleEffect(0.8)
                        } else if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(ChipInTheme.tertiaryLabel)
                            }
                        }
                    }
                    .padding(12)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding()

                    if results.isEmpty && !query.isEmpty && !isSearching {
                        VStack(spacing: 12) {
                            Text("🔍").font(.system(size: 40))
                            Text("No expenses found for \"\(query)\"")
                                .foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(results) { expense in
                            ExpenseRow(expense: expense)
                                .listRowBackground(ChipInTheme.card)
                                .listRowSeparatorTint(ChipInTheme.elevated)
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Search")
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { focused = true }
        }
    }

    private func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let userId = auth.currentUser?.id else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        let paid: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .ilike("title", pattern: "%\(trimmed)%")
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value) ?? []

        results = paid
    }
}
