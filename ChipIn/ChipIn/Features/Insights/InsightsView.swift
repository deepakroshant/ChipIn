import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = InsightsViewModel()
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if vm.isLoading && vm.categoryStats.isEmpty {
                        ProgressView()
                            .tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let err = vm.error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundStyle(ChipInTheme.danger)
                            Text(err)
                                .font(.subheadline)
                                .foregroundStyle(ChipInTheme.secondaryLabel)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { if let id = auth.currentUser?.id { await vm.load(userId: id) } }
                            }
                            .foregroundStyle(ChipInTheme.accent)
                        }
                        .padding(32)
                    } else if vm.categoryStats.isEmpty && vm.monthlyTotal == 0 {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 44))
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                            Text("No spending data yet")
                                .font(.headline).foregroundStyle(ChipInTheme.label)
                            Text("Add expenses to see your insights")
                                .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity).padding(40)
                    }

                    // Monthly total card
                    if !vm.isLoading || vm.monthlyTotal > 0 {
                    StatCard(title: "Spent This Month", value: vm.monthlyTotal, color: ChipInTheme.accent)
                        .padding(.horizontal)
                    }

                    // Category donut chart
                    if !vm.categoryStats.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("By Category")
                                .font(.headline)
                                .foregroundStyle(ChipInTheme.label)
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
                                            .foregroundStyle(ChipInTheme.label)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(stat.total, format: .currency(code: "CAD"))
                                            .foregroundStyle(ChipInTheme.secondaryLabel)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Settlement history
                    if !vm.settlements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Settlement History")
                                .font(.headline)
                                .foregroundStyle(ChipInTheme.label)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(vm.settlements) { settlement in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(ChipInTheme.success)
                                        Text(settlement.settledAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(ChipInTheme.secondaryLabel)
                                        Spacer()
                                        Text(settlement.amount, format: .currency(code: "CAD"))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(ChipInTheme.success)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().background(ChipInTheme.elevated)
                                }
                            }
                        }
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(ChipInTheme.background)
            .navigationTitle("Insights")
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
            .refreshable {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id { await vm.load(userId: id) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExport = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(ChipInTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                ExportSheetView()
                    .environment(auth)
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
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value, format: .currency(code: "CAD"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct ExportSheetView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var isExporting = false
    @State private var exportURL: URL?
    private let service = ExportService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(ChipInTheme.accent)
                    Text("Export Expenses").font(.title2.bold()).foregroundStyle(ChipInTheme.label)
                    Text("Exports all expenses you paid as a CSV file for accounting or reimbursement.")
                        .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button {
                        Task { await export() }
                    } label: {
                        if isExporting { ProgressView().tint(.black) }
                        else { Text("Export CSV").fontWeight(.semibold).foregroundStyle(.black) }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(ChipInTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .disabled(isExporting)
                    if let url = exportURL {
                        ExportShareSheet(items: [url])
                    }
                }
            }
            .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(ChipInTheme.secondaryLabel)
            }}
        }
    }

    private func export() async {
        guard let userId = auth.currentUser?.id else { return }
        isExporting = true
        defer { isExporting = false }
        let expenses: [Expense] = (try? await supabase
            .from("expenses").select()
            .eq("paid_by", value: userId)
            .order("created_at", ascending: false)
            .execute().value) ?? []
        exportURL = service.generateCSV(expenses: expenses)
    }
}
