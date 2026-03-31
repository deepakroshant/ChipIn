import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(Color(hex: "#F97316"))
                .clipShape(Circle())
                .shadow(color: Color(hex: "#F97316").opacity(0.5), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
