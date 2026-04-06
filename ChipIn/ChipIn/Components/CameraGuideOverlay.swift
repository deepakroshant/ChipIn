import SwiftUI

/// Animated corner-bracket frame overlay for the receipt camera.
struct CameraGuideOverlay: View {
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1.05

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: 280, height: 380)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 280, height: 380)
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: scale
                )

            CornerBrackets()
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: scale
                )

            VStack {
                Spacer()
                Text("Frame the full receipt")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
            }
        }
        .opacity(opacity)
        .onAppear {
            scale = 0.98
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.6)) { opacity = 0 }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CornerBrackets: View {
    private let size: CGFloat = 24
    private let thickness: CGFloat = 3
    private let w: CGFloat = 280
    private let h: CGFloat = 380
    private let r: CGFloat = 12

    var body: some View {
        ZStack {
            cornerBracket().offset(x: -(w / 2 - r), y: -(h / 2 - r))
            cornerBracket().rotationEffect(.degrees(90)).offset(x: (w / 2 - r), y: -(h / 2 - r))
            cornerBracket().rotationEffect(.degrees(180)).offset(x: (w / 2 - r), y: (h / 2 - r))
            cornerBracket().rotationEffect(.degrees(270)).offset(x: -(w / 2 - r), y: (h / 2 - r))
        }
    }

    private func cornerBracket() -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: size, y: 0))
        }
        .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}
