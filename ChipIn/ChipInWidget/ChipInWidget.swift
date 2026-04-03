import WidgetKit
import SwiftUI

// MARK: - Shared data model

struct WidgetBalance {
    let name: String
    let net: Double // positive = they owe me, negative = I owe them
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let netBalance: Double
    let topBalances: [WidgetBalance]
}

// MARK: - Data reader

struct WidgetDataReader {
    static let suiteName = "group.com.deepakroshant.chipin"

    static func read() -> WidgetEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        let net = defaults?.double(forKey: "netBalance") ?? 0
        let rawBalances = defaults?.array(forKey: "topBalances") as? [[String: Any]] ?? []
        let balances = rawBalances.compactMap { dict -> WidgetBalance? in
            guard let name = dict["name"] as? String,
                  let netVal = dict["net"] as? Double else { return nil }
            return WidgetBalance(name: name, net: netVal)
        }
        return WidgetEntry(date: .now, netBalance: net, topBalances: balances)
    }
}

// MARK: - Timeline provider

struct ChipInProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: .now,
            netBalance: 42.50,
            topBalances: [
                WidgetBalance(name: "Alex", net: 25.00),
                WidgetBalance(name: "Jordan", net: -17.50)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetDataReader.read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetDataReader.read()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget views

struct ChipInWidgetEntryView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .systemLarge: largeView
        default: smallView
        }
    }

    // MARK: Small — net balance only

    private var smallView: some View {
        ZStack {
            Color(hex: "#0E0E10")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color(hex: "#FF8C42"))
                        .font(.caption.bold())
                    Text("ChipIn")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "#FF8C42"))
                }
                Spacer()
                if entry.netBalance == 0 {
                    Text("🎉").font(.title2)
                    Text("Settled").font(.caption).foregroundStyle(.white.opacity(0.6))
                } else {
                    Text(entry.netBalance >= 0 ? "You're owed" : "You owe")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(abs(entry.netBalance), format: .currency(code: "CAD"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.netBalance >= 0 ? Color(hex: "#34D399") : Color(hex: "#FCA5A5"))
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(Color(hex: "#0E0E10"), for: .widget)
    }

    // MARK: Medium — balance + top 2 people

    private var mediumView: some View {
        ZStack {
            Color(hex: "#0E0E10")
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color(hex: "#FF8C42"))
                            .font(.caption.bold())
                        Text("ChipIn")
                            .font(.caption.bold())
                            .foregroundStyle(Color(hex: "#FF8C42"))
                    }
                    Spacer()
                    if entry.netBalance == 0 {
                        Text("🎉 All clear!")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    } else {
                        Text(entry.netBalance >= 0 ? "Owed to you" : "You owe")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(abs(entry.netBalance), format: .currency(code: "CAD"))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(entry.netBalance >= 0 ? Color(hex: "#34D399") : Color(hex: "#FCA5A5"))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Balances")
                        .font(.caption2.uppercaseSmallCaps())
                        .foregroundStyle(.white.opacity(0.4))

                    if entry.topBalances.isEmpty {
                        Text("No balances")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        ForEach(entry.topBalances.prefix(2), id: \.name) { b in
                            HStack {
                                Text(b.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Text(abs(b.net), format: .currency(code: "CAD"))
                                    .font(.caption.bold())
                                    .foregroundStyle(b.net >= 0 ? Color(hex: "#34D399") : Color(hex: "#FCA5A5"))
                            }
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(Color(hex: "#0E0E10"), for: .widget)
    }

    // MARK: Large — balance + all top people

    private var largeView: some View {
        ZStack {
            Color(hex: "#0E0E10")
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color(hex: "#FF8C42"))
                        Text("ChipIn")
                            .font(.headline.bold())
                            .foregroundStyle(Color(hex: "#FF8C42"))
                    }
                    Spacer()
                    Text(entry.netBalance >= 0 ? "Owed to you" : "You owe")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(abs(entry.netBalance), format: .currency(code: "CAD"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.netBalance >= 0 ? Color(hex: "#34D399") : Color(hex: "#FCA5A5"))
                }

                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

                if entry.topBalances.isEmpty {
                    Text("All settled up! 🎉")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(entry.topBalances, id: \.name) { b in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(b.name.prefix(1)).uppercased())
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(b.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(b.net >= 0 ? "owes you" : "you owe")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Text(abs(b.net), format: .currency(code: "CAD"))
                                .font(.subheadline.bold())
                                .foregroundStyle(b.net >= 0 ? Color(hex: "#34D399") : Color(hex: "#FCA5A5"))
                        }
                    }
                }
                Spacer()
                Text("Tap to open ChipIn")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(16)
        }
        .containerBackground(Color(hex: "#0E0E10"), for: .widget)
    }
}

// MARK: - Widget bundle entry

struct ChipInWidget: Widget {
    let kind: String = "ChipInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChipInProvider()) { entry in
            ChipInWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ChipIn Balance")
        .description("See who owes you and who you owe at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Color extension (widget can't import ChipInTheme)

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

// MARK: - Preview

#Preview(as: .systemSmall) {
    ChipInWidget()
} timeline: {
    WidgetEntry(date: .now, netBalance: 42.50, topBalances: [
        WidgetBalance(name: "Alex", net: 42.50)
    ])
    WidgetEntry(date: .now, netBalance: -18.00, topBalances: [
        WidgetBalance(name: "Jordan", net: -18.00)
    ])
}
