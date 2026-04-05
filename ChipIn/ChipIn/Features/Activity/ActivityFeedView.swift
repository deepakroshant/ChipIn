import SwiftUI

struct ActivityFeedView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = ActivityFeedViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().tint(ChipInTheme.accent)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.items) { item in
                                ActivityRow(item: item)
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                Divider()
                                    .background(ChipInTheme.elevated)
                                    .padding(.leading, 68)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        if let id = auth.currentUser?.id { await vm.load(currentUserId: id) }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id { await vm.load(currentUserId: id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id { await vm.load(currentUserId: id) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("📭").font(.system(size: 48))
            Text("Nothing yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(ChipInTheme.label)
            Text("When friends add expenses you're included in or settle up, they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

private struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(ChipInTheme.avatarColor(for: item.actorId.uuidString))
                    .frame(width: 44, height: 44)
                Text(String(item.actorName.prefix(1)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(rowTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChipInTheme.label)
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                Text(item.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
            }

            Spacer()

            Text(rowAmount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor)
        }
    }

    private var rowTitle: String {
        switch item.kind {
        case .expenseAdded(let e): return "\(item.actorName) added \u{201C}\(e.title)\u{201D}"
        case .settled: return "\(item.actorName) settled up"
        }
    }

    private var rowSubtitle: String {
        switch item.kind {
        case .expenseAdded: return "You're included in this expense"
        case .settled: return "Payment marked complete"
        }
    }

    private var rowAmount: String {
        switch item.kind {
        case .expenseAdded(let e):
            return e.cadAmount.formatted(.currency(code: "CAD"))
        case .settled(let s):
            return s.amount.formatted(.currency(code: "CAD"))
        }
    }

    private var amountColor: Color {
        switch item.kind {
        case .settled: return ChipInTheme.success
        default: return ChipInTheme.label
        }
    }
}
