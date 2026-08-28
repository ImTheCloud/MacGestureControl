// HUDOverlay.swift
// Floating on-screen confirmation shown when a gesture fires.
import SwiftUI
import AppKit

final class HUDManager {
    static let shared = HUDManager()

    private let panelSize = NSSize(width: 244, height: 84)
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private let data = HUDData()

    private init() {}

    func show(icon: String, title: String, subtitle: String? = nil, progress: Float? = nil) {
        guard AppSettings.shared.showHUD else { return }

        // The panel is AppKit, so it is only ever created and touched on the main thread.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show(icon: icon, title: title, subtitle: subtitle, progress: progress) }
            return
        }

        let panel = ensurePanel()

        data.icon = icon
        data.title = title
        data.subtitle = subtitle
        data.progress = progress
        data.isVisible = true

        position(panel)
        panel.orderFrontRegardless()

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.data.isVisible = false
            // Let the fade-out animation finish before pulling the window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !self.data.isVisible { self.panel?.orderOut(nil) }
            }
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(data: data))

        self.panel = panel
        return panel
    }

    /// Shown on the display the pointer is on, so it appears where the user is looking.
    private func position(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let area = screen?.visibleFrame else { return }

        panel.setFrameOrigin(NSPoint(
            x: area.midX - panelSize.width / 2,
            y: area.maxY - panelSize.height - 16
        ))
    }
}

final class HUDData: ObservableObject {
    @Published var icon: String = "speaker.wave.3.fill"
    @Published var title: String = "Volume"
    @Published var subtitle: String?
    @Published var progress: Float?
    @Published var isVisible: Bool = false
}

struct HUDView: View {
    @ObservedObject var data: HUDData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 38, height: 38)
                Image(systemName: data.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(data.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let progress = data.progress {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if let progress = data.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.12))
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
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
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        )
        .scaleEffect(data.isVisible ? 1.0 : 0.86)
        .opacity(data.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: data.isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
