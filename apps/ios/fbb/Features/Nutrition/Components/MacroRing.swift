import SwiftUI

/// Reusable circular progress ring used for the calorie hero and the 3
/// macro mini-rings. Renders a track + a fill arc that animates from 0 to
/// `progress` (clamped to 0...1.5 — over-target shows the warning ring).
struct MacroRing: View {
    let progress: Double         // 0...1+ (1.0 = at target, > 1.0 = over)
    let lineWidth: CGFloat
    let tint: Color
    let trackTint: Color

    init(
        progress: Double,
        lineWidth: CGFloat = 10,
        tint: Color = .fbbOrange,
        trackTint: Color? = nil
    ) {
        self.progress = max(0, min(progress, 1.5))
        self.lineWidth = lineWidth
        self.tint = tint
        self.trackTint = trackTint ?? tint.opacity(0.18)
    }

    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackTint, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(animated, 1.0))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if animated > 1.0 {
                // Over-target: layer a warning arc beyond 1.0
                Circle()
                    .trim(from: 0, to: animated - 1.0)
                    .stroke(
                        Color.semanticWarning,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animated = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.easeOut(duration: 0.45)) { animated = new }
        }
        .accessibilityHidden(true)  // labels live on the wrapping view
    }
}

#Preview {
    HStack(spacing: 24) {
        ZStack {
            MacroRing(progress: 0.65, lineWidth: 14, tint: .fbbOrange)
                .frame(width: 100, height: 100)
            VStack {
                Text("65%").font(.fbb.metric)
            }
        }
        ZStack {
            MacroRing(progress: 1.18, lineWidth: 14, tint: .fbbOrange)
                .frame(width: 100, height: 100)
            VStack { Text("118%").font(.fbb.metric) }
        }
    }
    .padding()
    .background(Color.fbbBackground)
}
