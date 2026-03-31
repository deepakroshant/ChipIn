import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Decimal
    let isOwed: Bool
}

// MARK: - Timeline Provider
struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, balance: 240.00, isOwed: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> BalanceEntry {
        let defaults = UserDefaults(suiteName: "group.com.yourname.chipin")
        let balance = Decimal(defaults?.double(forKey: "netBalance") ?? 0)
        return BalanceEntry(date: .now, balance: abs(balance), isOwed: balance >= 0)
    }
}

// MARK: - Small Widget View
struct BalanceWidgetView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(Color(hex: "#F97316"))
                    .font(.caption)
                Text("Chip In")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.isOwed ? "Owed to you" : "You owe")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.balance, format: .currency(code: "CAD"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(entry.isOwed ? Color(hex: "#10B981") : Color(hex: "#F87171"))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(Color(hex: "#1C1C1E"), for: .widget)
    }
}

// MARK: - Lock Screen Widget View
struct LockScreenWidgetView: View {
    let entry: BalanceEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isOwed ? "arrow.down.circle" : "arrow.up.circle")
            Text(entry.balance, format: .currency(code: "CAD"))
                .fontWeight(.semibold)
        }
        .font(.caption)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Configuration
struct ChipInBalanceWidget: Widget {
    let kind = "ChipInBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Chip In Balance")
        .description("See your current balance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ChipInLockScreenWidget: Widget {
    let kind = "ChipInLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Chip In")
        .description("Balance on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Bundle
@main
struct ChipInWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChipInBalanceWidget()
        ChipInLockScreenWidget()
    }
}

// Hex color helper (duplicated here since widgets are a separate target)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
