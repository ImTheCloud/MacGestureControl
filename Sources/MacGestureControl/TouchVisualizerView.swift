// TouchVisualizerView.swift
// Live view of what the engine is reading from the trackpad.
import SwiftUI

struct TouchVisualizerView: View {
    @ObservedObject private var engine = MultitouchEngine.shared

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text("LIVE TRACKPAD")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Text(fingerLabel)
                    .font(.system(size: 9, weight: engine.activeTouches.isEmpty ? .regular : .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(engine.activeTouches.isEmpty
                                       ? Color.primary.opacity(0.06)
                                       : Color.accentColor.opacity(0.18))
                    )
                    .foregroundColor(engine.activeTouches.isEmpty ? .secondary : .accentColor)
            }

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
                        )

                    // Corner hot zones, matching the engine's 18% corner regions.
                    ForEach(Array(cornerPoints(in: geo.size).enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Color.secondary.opacity(0.22))
                            .frame(width: 4, height: 4)
                            .position(point)
                    }

                    ForEach(engine.activeTouches) { touch in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.blue, .purple.opacity(0.85)],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 18, height: 18)
                            .position(
                                x: touch.normalizedX * geo.size.width,
                                y: touch.normalizedY * geo.size.height
                            )
                    }
                }
                .animation(.easeOut(duration: 0.08), value: engine.activeTouches.count)
            }
            .frame(height: 74)
        }
        // The engine only publishes touch positions while this view is on screen.
        .onAppear { engine.beginRadarUpdates() }
        .onDisappear { engine.endRadarUpdates() }
    }

    private var fingerLabel: String {
        switch engine.activeTouches.count {
        case 0: return "Touch the trackpad"
        case 1: return "1 finger"
        case let count: return "\(count) fingers"
        }
    }

    private func cornerPoints(in size: CGSize) -> [CGPoint] {
        let inset: CGFloat = 11
        return [
            CGPoint(x: inset, y: inset),
            CGPoint(x: size.width - inset, y: inset),
            CGPoint(x: inset, y: size.height - inset),
            CGPoint(x: size.width - inset, y: size.height - inset)
        ]
    }
}
