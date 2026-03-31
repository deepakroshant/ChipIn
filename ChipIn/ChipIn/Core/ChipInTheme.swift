import SwiftUI
import UIKit

/// Central palette — higher contrast for readability on dark backgrounds.
enum ChipInTheme {
    static let background = Color(hex: "#0E0E10")
    static let card = Color(hex: "#252528")
    static let elevated = Color(hex: "#343438")
    static let accent = Color(hex: "#FF8C42")
    static let success = Color(hex: "#34D399")
    static let danger = Color(hex: "#FCA5A5")
    /// Primary text — near-white for WCAG on dark surfaces.
    static let label = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let secondaryLabel = Color(red: 0.82, green: 0.82, blue: 0.86)
    static let tertiaryLabel = Color(red: 0.62, green: 0.62, blue: 0.68)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#FF8C42"), Color(hex: "#FF5500")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#1A1A1E"), Color(hex: "#0E0E10")],
        startPoint: .top, endPoint: .bottom
    )

    // Spacing / layout
    static let padding: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 20

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
            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    func chipInSection() -> some View {
        self.padding(ChipInTheme.padding)
    }
}

enum ChipInNavigationAppearance {
    static func apply() {
        let card = UIColor(red: 37 / 255, green: 37 / 255, blue: 40 / 255, alpha: 1)
        let muted = UIColor(red: 0.62, green: 0.62, blue: 0.66, alpha: 1)
        let orange = UIColor(red: 255 / 255, green: 140 / 255, blue: 66 / 255, alpha: 1)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = card
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .white

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = card
        tab.stackedLayoutAppearance.normal.iconColor = muted
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: muted]
        tab.stackedLayoutAppearance.selected.iconColor = orange
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: orange]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().unselectedItemTintColor = muted
        UITabBar.appearance().tintColor = orange
    }
}
