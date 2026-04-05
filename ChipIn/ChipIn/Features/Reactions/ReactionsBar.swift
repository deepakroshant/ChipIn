import SwiftUI

struct ReactionsBar: View {
    let expenseId: UUID
    let currentUserId: UUID
    @State private var reactions: [Reaction] = []
    private let service = ReactionsService()
    private let emojis = ["👍", "🔥", "💀", "😂", "🙏"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    reactionButton(emoji)
                }
            }
            .padding(.vertical, 4)
        }
        .task { await load() }
    }

    private func reactionButton(_ emoji: String) -> some View {
        let count = reactions.filter { $0.emoji == emoji }.count
        let isMine = reactions.contains { $0.userId == currentUserId && $0.emoji == emoji }

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await toggle(emoji: emoji) }
        } label: {
            HStack(spacing: 4) {
                Text(emoji).font(.body)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isMine ? ChipInTheme.onPrimary : ChipInTheme.label)
                }
            }
            .padding(.horizontal, count > 0 ? 10 : 8)
            .padding(.vertical, 6)
            .background(isMine ? ChipInTheme.accent : ChipInTheme.elevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isMine ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isMine ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMine)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        reactions = (try? await service.fetchReactions(expenseId: expenseId)) ?? []
    }

    private func toggle(emoji: String) async {
        let snapshot = reactions
        // Optimistic update
        if reactions.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
            reactions.removeAll { $0.userId == currentUserId && $0.emoji == emoji }
        } else {
            reactions.append(Reaction(
                id: UUID(), expenseId: expenseId, userId: currentUserId,
                emoji: emoji, createdAt: Date()
            ))
        }
        do {
            try await service.toggleReaction(expenseId: expenseId, userId: currentUserId, emoji: emoji, existing: snapshot)
        } catch {
            reactions = snapshot // roll back on error
        }
    }
}
