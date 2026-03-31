import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly total card
                    StatCard(title: "Spent This Month", value: vm.monthlyTotal, color: Color(hex: "#F97316"))
                        .padding(.horizontal)

                    // Category donut chart
                    if !vm.categoryStats.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("By Category")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            Chart(vm.categoryStats) { stat in
                                SectorMark(
                                    angle: .value("Amount", stat.total),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2
                                )
                                .foregroundStyle(stat.colour)
                                .cornerRadius(4)
                            }
                            .frame(height: 220)
                            .padding(.horizontal)

                            VStack(spacing: 10) {
                                ForEach(vm.categoryStats) { stat in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(stat.colour)
                                            .frame(width: 10, height: 10)
                                        Text("\(stat.emoji) \(stat.category)")
                                            .foregroundStyle(.white)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(stat.total, format: .currency(code: "CAD"))
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Settlement history
                    if !vm.settlements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Settlement History")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(vm.settlements) { settlement in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(Color(hex: "#10B981"))
                                        Text(settlement.settledAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(settlement.amount, format: .currency(code: "CAD"))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color(hex: "#10B981"))
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().background(Color(hex: "#2C2C2E"))
                                }
                            }
                        }
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Insights")
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id { await vm.load(userId: id) }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value, format: .currency(code: "CAD"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
