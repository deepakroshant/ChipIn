import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }
        }
        .onAppear { spawnParticles() }
        .allowsHitTesting(false)
    }

    private func spawnParticles() {
        let colors: [Color] = [.orange, .yellow, .green, .blue, .pink, .purple]
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: -180...180),
                y: CGFloat.random(in: -300...100),
                size: CGFloat.random(in: 6...14),
                color: colors.randomElement()!,
                opacity: Double.random(in: 0.7...1.0)
            )
        }
        withAnimation(.easeOut(duration: 1.5)) {
            for i in particles.indices {
                particles[i].y += CGFloat.random(in: 200...400)
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
