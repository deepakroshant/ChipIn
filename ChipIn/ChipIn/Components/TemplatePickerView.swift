import SwiftUI

struct TemplatePickerView: View {
    let templates: [ExpenseTemplate]
    let onSelect: (ExpenseTemplate) -> Void
    let onDelete: (ExpenseTemplate) -> Void

    var body: some View {
        if templates.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick templates")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                    .padding(.horizontal, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates) { template in
                            Button {
                                onSelect(template)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(categoryEmoji(template.category))
                                        .font(.title3)
                                    Text(template.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ChipInTheme.label)
                                        .lineLimit(1)
                                    Text(template.title)
                                        .font(.caption2)
                                        .foregroundStyle(ChipInTheme.secondaryLabel)
                                        .lineLimit(1)
                                }
                                .padding(12)
                                .background(ChipInTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(template)
                                } label: {
                                    Label("Delete Template", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryEmoji(_ cat: String) -> String {
        switch cat {
        case "food": return "🍕"
        case "travel": return "🚗"
        case "rent": return "🏠"
        case "fun": return "🎉"
        case "utilities": return "⚡"
        default: return "📋"
        }
    }
}
