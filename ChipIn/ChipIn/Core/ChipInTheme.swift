import SwiftUI
import UIKit

/// Central palette — Emerald Obsidian (design-reference/emerald-obsidian).
enum ChipInTheme {
    /// User-chosen accent from Profile (`accentColor` in UserDefaults). Defaults to orange.
    private static var accentHex: String {
        UserDefaults.standard.string(forKey: "accentColor") ?? "#F97316"
    }

    static let background = Color(hex: "#0E0E10")
    static let surfaceHeader = Color(hex: "#1B1B1D")
    /// Material 3 surface-container
    static let card = Color(hex: "#201F21")
    static let elevated = Color(hex: "#2A2A2C")
    static let surfaceContainerHighest = Color(hex: "#353437")
    static let surfaceTabBar = Color(hex: "#353437")
    static var accent: Color { Color(hex: accentHex) }
    static let tertiary = Color(hex: "#FFB95F")
    /// Stitch secondary / mint — positive balances & “you’re owed”
    static let success = Color(hex: "#4EDEA3")
    static let danger = Color(hex: "#FCA5A5")
    /// On-primary for text on orange / gradient CTAs
    static let onPrimary = Color(hex: "#532200")
    /// M3 on-surface-variant
    static let onSurfaceVariant = Color(hex: "#DDC1B3")
    /// Primary text — near-white for WCAG on dark surfaces.
    static let label = Color(hex: "#E5E1E4")
    static let secondaryLabel = Color(red: 0.82, green: 0.82, blue: 0.86)
    static let tertiaryLabel = Color(red: 0.62, green: 0.62, blue: 0.68)

    // Gradients (follow user accent)
    static var accentGradient: LinearGradient {
        let a = accent
        return LinearGradient(
            colors: [a, a.opacity(0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static var ctaGradient: LinearGradient {
        let a = accent
        return LinearGradient(
            colors: [a, a.opacity(0.82)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#1A1A1E"), Color(hex: "#0E0E10")],
        startPoint: .top, endPoint: .bottom
    )

    // Spacing / layout (squircle ≈ 32pt in mocks)
    static let padding: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 24
    static let squircleRadius: CGFloat = 28

    // Animations
    static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.72)
    static let easeDefault: Animation = .easeInOut(duration: 0.2)

    // Avatar colors (deterministic by index)
    static let avatarColors: [Color] = [
        Color(hex: "#FF8C42"), Color(hex: "#3B82F6"), Color(hex: "#10B981"),
        Color(hex: "#8B5CF6"), Color(hex: "#EC4899"), Color(hex: "#FBBF24")
    ]
    static func avatarColor(for name: String) -> Color {
        let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % avatarColors.count
        return avatarColors[index]
    }
}

extension View {
    func chipInCard() -> some View {
        self
            .background(ChipInTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    }

    func chipInSection() -> some View {
        self.padding(ChipInTheme.padding)
    }
}

enum ChipInNavigationAppearance {
    static func apply() {
        let header = UIColor(red: 27 / 255, green: 27 / 255, blue: 29 / 255, alpha: 1)
        let tabBg = UIColor(red: 53 / 255, green: 52 / 255, blue: 55 / 255, alpha: 1)
        let muted = UIColor(red: 0.87, green: 0.76, blue: 0.70, alpha: 1)
        let hex = UserDefaults.standard.string(forKey: "accentColor") ?? "#F97316"
        let accent = UIColor(chipInHex: hex) ?? UIColor(red: 249 / 255, green: 115 / 255, blue: 22 / 255, alpha: 1)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = header
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .white

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = tabBg
        tab.shadowColor = .clear
        tab.stackedLayoutAppearance.normal.iconColor = muted
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: muted]
        tab.stackedLayoutAppearance.selected.iconColor = accent
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().unselectedItemTintColor = muted
        UITabBar.appearance().tintColor = accent
    }
}

private extension UIColor {
    /// Parses `#RRGGBB` from Profile accent.
    convenience init?(chipInHex: String) {
        let hex = chipInHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else { return nil }
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
