import SwiftUI
import Supabase

enum SpendingPersonality: String {
    case banker = "The Banker"
    case fairOne = "The Fair One"
    case ghost = "The Ghost"
    case wildCard = "The Wild Card"
    case regular = "The Regular"

    var emoji: String {
        switch self {
        case .banker: return "🏦"
        case .fairOne: return "⚖️"
        case .ghost: return "👻"
        case .wildCard: return "🎲"
        case .regular: return "🍕"
        }
    }

    var tagline: String {
        switch self {
        case .banker: return "You're always the one who covers the group."
        case .fairOne: return "You settle fast. Your friends love you for it."
        case .ghost: return "Your debts are ageing. Time to settle up 👀"
        case .wildCard: return "You spend across every category. Adventurous."
        case .regular: return "Creature of habit — and there's nothing wrong with that."
        }
    }

    var gradient: [Color] {
        switch self {
        case .banker: return [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.3, blue: 0.7)]
        case .fairOne: return [Color(red: 0.1, green: 0.7, blue: 0.5), Color(red: 0.0, green: 0.5, blue: 0.3)]
        case .ghost: return [Color(red: 0.4, green: 0.4, blue: 0.5), Color(red: 0.2, green: 0.2, blue: 0.3)]
        case .wildCard: return [Color(red: 0.8, green: 0.3, blue: 0.9), Color(red: 0.5, green: 0.1, blue: 0.7)]
        case .regular: return [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.3, blue: 0.0)]
        }
    }
}

@MainActor
@Observable
final class SpendingPersonalityViewModel {
    var personality: SpendingPersonality?
    var isLoading = false

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let now = Date()

        let myExpenses: [Expense] = (try? await supabase
            .from("expenses").select()
            .eq("paid_by", value: userId)
            .limit(100)
            .execute().value) ?? []

        let myDebts: [ExpenseSplit] = (try? await supabase
            .from("expense_splits").select()
            .eq("user_id", value: userId)
            .limit(100)
            .execute().value) ?? []

        let unsettled = myDebts.filter { !$0.isSettled }
        if !unsettled.isEmpty {
            let expIds = unsettled.map(\.expenseId.uuidString)
            let exps: [Expense] = (try? await supabase
                .from("expenses")
                .select()
                .in("id", values: expIds)
                .limit(100)
                .execute()
                .value) ?? []
            if let oldest = exps.map(\.createdAt).min(),
               now.timeIntervalSince(oldest) > 21 * 86400 {
                personality = .ghost
                return
            }
        }

        let involvedIds = Set(myDebts.map(\.expenseId))
        let totalInvolved = max(1, myExpenses.count + involvedIds.subtracting(Set(myExpenses.map(\.id))).count)
        let paidRatio = Double(myExpenses.count) / Double(totalInvolved)

        let cats = Set(myExpenses.map(\.category)).count
        let topCatCount = myExpenses.isEmpty ? 0 :
            Dictionary(grouping: myExpenses, by: \.category)
            .values.map(\.count).max() ?? 0
        let topCatRatio = myExpenses.isEmpty ? 0 : Double(topCatCount) / Double(myExpenses.count)

        if paidRatio > 0.6 {
            personality = .banker
        } else if cats >= 4 {
            personality = .wildCard
        } else if topCatRatio > 0.7 && !myExpenses.isEmpty {
            personality = .regular
        } else {
            personality = .fairOne
        }
    }
}

struct SpendingPersonalityView: View {
    let userId: UUID
    @State private var vm = SpendingPersonalityViewModel()

    var body: some View {
        SwiftUI.Group {
            if vm.isLoading {
                ShimmerView(cornerRadius: 16, height: 100)
                    .padding(.horizontal)
            } else if let p = vm.personality {
                HStack(spacing: 16) {
                    Text(p.emoji).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.rawValue)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text(p.tagline)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    LinearGradient(colors: p.gradient, startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
        .task { await vm.load(userId: userId) }
    }
}
