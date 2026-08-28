// HUDOverlay.swift
import SwiftUI
import AppKit

class HUDManager {
    static let shared = HUDManager()

    private var hudWindow: NSPanel?
    private var dismissTimer: Timer?
    private var hudData = HUDData()

    private init() {
        setupWindow()
    }

    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 74),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: HUDView(data: hudData))
        panel.contentView = hostingView

        self.hudWindow = panel
    }

    func show(icon: String, title: String, subtitle: String? = nil, progress: Float? = nil) {
        guard AppSettings.shared.showHUD else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.hudWindow else { return }

            self.hudData.icon = icon
            self.hudData.title = title
            self.hudData.subtitle = subtitle
            self.hudData.progress = progress
            self.hudData.isVisible = true

            // Position at top-center of screen (just below menu bar like Dynamic Island)
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.origin.x + (screenRect.width - 220) / 2
                let y = screenRect.origin.y + screenRect.height - 90
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            panel.orderFrontRegardless()

            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hudData.isVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if !(self?.hudData.isVisible ?? false) {
                            self?.hudWindow?.orderOut(nil)
                        }
                    }
                }
            }
        }
    }
}

class HUDData: ObservableObject {
    @Published var icon: String = "speaker.wave.3.fill"
    @Published var title: String = "Volume"
    @Published var subtitle: String? = nil
    @Published var progress: Float? = 0.5
    @Published var isVisible: Bool = false
}

struct HUDView: View {
    @ObservedObject var data: HUDData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: data.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(data.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    if let progress = data.progress {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if let progress = data.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.12))
                                .frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 6)
                        }
                    }
                    .frame(height: 6)
                } else if let subtitle = data.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 220, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
        )
        .scaleEffect(data.isVisible ? 1.0 : 0.85)
        .opacity(data.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: data.isVisible)
    }
}
