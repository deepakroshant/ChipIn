import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(ChipInTheme.accent)
                .clipShape(Circle())
                .shadow(color: ChipInTheme.accent.opacity(0.45), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
