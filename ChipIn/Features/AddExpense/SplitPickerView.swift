import SwiftUI

struct SplitPickerView: View {
    @Binding var splitType: SplitType

    private let options: [(SplitType, String, String)] = [
        (.equal, "Equal", "person.2"),
        (.percent, "Percent", "percent"),
        (.exact, "Exact", "dollarsign"),
        (.byItem, "By Item", "list.bullet"),
        (.shares, "Shares", "chart.pie")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.0.rawValue) { type, label, icon in
                    Button {
                        splitType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.headline)
                            Text(label)
                                .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(splitType == type ? Color(hex: "#F97316") : Color(hex: "#2C2C2E"))
                        .foregroundStyle(splitType == type ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
