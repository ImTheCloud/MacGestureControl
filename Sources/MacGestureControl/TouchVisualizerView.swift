// TouchVisualizerView.swift
import SwiftUI

struct TouchVisualizerView: View {
    @ObservedObject var engine = MultitouchEngine.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Live Trackpad Radar", systemImage: "waveform.badge.magnifyingglass")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if !engine.activeTouches.isEmpty {
                    Text("\(engine.activeTouches.count) \(engine.activeTouches.count == 1 ? "Finger" : "Fingers")")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundColor(.blue)
                } else {
                    Text("Touch Trackpad")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Trackpad surface radar canvas
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )

                    // Corner indicators
                    cornerGuide(x: 14, y: 14)
                    cornerGuide(x: geo.size.width - 14, y: 14)
                    cornerGuide(x: 14, y: geo.size.height - 14)
                    cornerGuide(x: geo.size.width - 14, y: geo.size.height - 14)

                    // Active Touch Points
                    ForEach(engine.activeTouches) { touch in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.blue, .purple.opacity(0.8)],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 16
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: .blue.opacity(0.6), radius: 6, x: 0, y: 0)
                            .position(
                                x: touch.normalizedX * geo.size.width,
                                y: touch.normalizedY * geo.size.height
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: 110)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }

    private func cornerGuide(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
    }
}
