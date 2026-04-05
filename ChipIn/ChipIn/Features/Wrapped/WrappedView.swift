import SwiftUI

struct WrappedCard: Identifiable {
    let id = UUID()
    let emoji: String
    let headline: String
    let subheadline: String
    let detail: String
    let gradient: [Color]
}

struct WrappedView: View {
    let userId: UUID
    @Environment(\.dismiss) var dismiss
    @State private var cards: [WrappedCard] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if isLoading {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            } else if cards.isEmpty {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("📭").font(.system(size: 48))
                    Text("Not enough data yet")
                        .foregroundStyle(.white)
                        .font(.headline)
                    Text("Add some expenses and come back!")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.subheadline)
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.26))
                        .padding(.top, 8)
                }
            } else {
                cardStack
            }
        }
        .task { await buildCards() }
    }

    private var cardStack: some View {
        ZStack {
            LinearGradient(
                colors: cards[currentIndex].gradient,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: currentIndex)

            VStack {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<cards.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: i == currentIndex ? 20 : 8, height: 4)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.top, 56)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 20) {
                    Text(cards[currentIndex].emoji)
                        .font(.system(size: 80))
                        .animation(.spring(response: 0.4), value: currentIndex)

                    Text(cards[currentIndex].headline)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .animation(.spring(response: 0.4), value: currentIndex)

                    Text(cards[currentIndex].subheadline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text(cards[currentIndex].detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.horizontal, 32)
                .offset(x: dragOffset * 0.1)

                Spacer()

                HStack {
                    if currentIndex > 0 {
                        Button {
                            withAnimation(.spring(response: 0.4)) { currentIndex -= 1 }
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    if currentIndex < cards.count - 1 {
                        Button {
                            withAnimation(.spring(response: 0.4)) { currentIndex += 1 }
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2).foregroundStyle(.white.opacity(0.7))
                        }
                    } else {
                        Button("Done") { dismiss() }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4)) {
                if currentIndex < cards.count - 1 { currentIndex += 1 }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { v in dragOffset = v.translation.width }
                .onEnded { v in
                    withAnimation(.spring(response: 0.4)) {
                        dragOffset = 0
                        if v.translation.width < -50, currentIndex < cards.count - 1 {
                            currentIndex += 1
                        } else if v.translation.width > 50, currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }
                }
        )
    }

    private func buildCards() async {
        defer { isLoading = false }
        let year = Calendar.current.component(.year, from: Date())
        var comps = DateComponents(); comps.year = year; comps.month = 1; comps.day = 1
        guard let yearStart = Calendar.current.date(from: comps) else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let allExpenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .gte("created_at", value: formatter.string(from: yearStart))
            .execute()
            .value) ?? []

        let myExpenses = allExpenses.filter { $0.paidBy == userId }
        let splits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select()
            .eq("user_id", value: userId)
            .gte("created_at", value: formatter.string(from: yearStart))
            .execute()
            .value) ?? []

        let totalPaid = myExpenses.reduce(Decimal(0)) { $0 + $1.cadAmount }
        let topExpense = myExpenses.max(by: { $0.cadAmount < $1.cadAmount })

        var catTotals: [String: Decimal] = [:]
        for e in myExpenses { catTotals[e.category, default: 0] += e.cadAmount }
        let topCat = catTotals.max(by: { $0.value < $1.value })

        func catEmoji(_ cat: String) -> String {
            switch cat {
            case "food": return "🍕"; case "travel": return "✈️"
            case "rent": return "🏠"; case "fun": return "🎉"
            case "utilities": return "⚡"; default: return "📦"
            }
        }

        var result: [WrappedCard] = []

        result.append(WrappedCard(
            emoji: "🎓",
            headline: "\(year) Wrapped",
            subheadline: "Your year in ChipIn",
            detail: "Tap to see how the money flowed →",
            gradient: [Color(red: 0.9, green: 0.4, blue: 0.1), Color(red: 0.7, green: 0.1, blue: 0.5)]
        ))

        if totalPaid > 0 {
            result.append(WrappedCard(
                emoji: "💰",
                headline: totalPaid.formatted(.currency(code: "CAD")),
                subheadline: "Total you covered this year",
                detail: "Across \(myExpenses.count) expense\(myExpenses.count == 1 ? "" : "s") you paid for",
                gradient: [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.3, blue: 0.7)]
            ))
        }

        if let (cat, amt) = topCat {
            result.append(WrappedCard(
                emoji: catEmoji(cat),
                headline: cat.capitalized,
                subheadline: "Your top spending category",
                detail: "\(amt.formatted(.currency(code: "CAD"))) this year on \(cat)",
                gradient: [Color(red: 0.1, green: 0.7, blue: 0.4), Color(red: 0.0, green: 0.5, blue: 0.3)]
            ))
        }

        if let top = topExpense {
            result.append(WrappedCard(
                emoji: "🤯",
                headline: top.cadAmount.formatted(.currency(code: "CAD")),
                subheadline: "Your biggest single expense",
                detail: "\"\(top.title)\" — that was a big one.",
                gradient: [Color(red: 0.8, green: 0.1, blue: 0.3), Color(red: 0.5, green: 0.0, blue: 0.2)]
            ))
        }

        if !splits.isEmpty {
            result.append(WrappedCard(
                emoji: "🫂",
                headline: "\(splits.count) split\(splits.count == 1 ? "" : "s")",
                subheadline: "Bills you shared this year",
                detail: "ChipIn kept the math fair so friendships stayed intact",
                gradient: [Color(red: 0.5, green: 0.1, blue: 0.9), Color(red: 0.3, green: 0.0, blue: 0.7)]
            ))
        }

        result.append(WrappedCard(
            emoji: "🍊",
            headline: "See you in \(year + 1)",
            subheadline: "Keep splitting fairly",
            detail: "Share your Wrapped and invite friends to ChipIn",
            gradient: [Color(red: 0.9, green: 0.5, blue: 0.05), Color(red: 0.7, green: 0.25, blue: 0.0)]
        ))

        cards = result
    }
}
