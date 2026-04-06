import SwiftUI

struct ActivityFeedView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = ActivityFeedViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isLoading && vm.items.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { _ in
                            ActivityRowSkeleton()
                            Divider().background(ChipInTheme.elevated).padding(.leading, 68)
                        }
                    }
                    .padding(.top, 8)
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
            .navigationBarTitleDisplayMode(.inline)
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
        EmptyStateView(
            emoji: "🌊",
            headline: "Your feed is quiet",
            subheadline: "Add an expense or settle up with a friend — it'll show up here for everyone involved."
        )
    }
}

private struct ActivityRow: View {
    @Environment(AuthManager.self) private var auth
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
        case .expenseAdded(let e):
            let who = isYou(item.actorId) ? "You" : item.actorName
            return "\(who) added \u{201C}\(e.title)\u{201D}"
        case .settled(let s):
            let peer = item.peerName ?? "Someone"
            if isYou(s.fromUserId) {
                return "You settled with \(peer)"
            }
            if isYou(s.toUserId) {
                return "\(item.actorName) settled with you"
            }
            return "\(item.actorName) settled with \(peer)"
        }
    }

    private var rowSubtitle: String {
        switch item.kind {
        case .expenseAdded(let e):
            if isYou(e.paidBy) {
                return "Paid by you · others owe their share"
            }
            return "You're in this split"
        case .settled: return "Payment marked complete"
        }
    }

    private func isYou(_ id: UUID) -> Bool {
        guard let uid = auth.currentUser?.id else { return false }
        return uid == id
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
