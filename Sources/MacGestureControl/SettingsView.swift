// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var engine = MultitouchEngine.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @State private var showAdvanced: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Header
            headerView
                .padding(.top, 4)

            Divider().opacity(0.5)

            // MARK: - Core Active Gestures
            VStack(alignment: .leading, spacing: 7) {
                Text("GESTURES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                gestureRow(
                    id: "fourFingerVertical",
                    icon: "speaker.wave.3.fill",
                    title: "4-Finger Swipe",
                    subtitle: "Swipe up / down on trackpad",
                    binding: $settings.fourFingerVerticalAction
                )

                gestureRow(
                    id: "fourFingerTap",
                    icon: "playpause.fill",
                    title: "4-Finger Tap",
                    subtitle: "Brief tap with 4 fingers",
                    binding: $settings.fourFingerTapAction
                )

                gestureRow(
                    id: "threeFingerTap",
                    icon: "camera.fill",
                    title: "3-Finger Tap",
                    subtitle: "Brief tap with 3 fingers",
                    binding: $settings.threeFingerTapAction
                )
            }

            // MARK: - Advanced / More Gestures (Expandable)
            if showAdvanced {
                VStack(alignment: .leading, spacing: 7) {
                    Text("MORE GESTURES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                    gestureRow(
                        id: "threeFingerHorizontal",
                        icon: "arrow.left.and.right",
                        title: "3-Finger Swipe",
                        subtitle: "Swipe left / right on trackpad",
                        binding: $settings.threeFingerHorizontalAction
                    )

                    gestureRow(
                        id: "twoFingerTap",
                        icon: "hand.tap.fill",
                        title: "2-Finger Tap",
                        subtitle: "Tap with 2 fingers",
                        binding: $settings.twoFingerTapAction
                    )

                    gestureRow(
                        id: "cornerTopLeft",
                        icon: "square.topthird.inset.filled",
                        title: "Top-Left Corner",
                        subtitle: "Tap trackpad top-left corner",
                        binding: $settings.cornerTopLeftAction
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showAdvanced.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showAdvanced ? "chevron.up" : "plus.circle")
                    Text(showAdvanced ? "Hide Extra Gestures" : "More Gestures...")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            Divider().opacity(0.5)

            // MARK: - Preferences (3 Simple Essential Toggles)
            VStack(spacing: 6) {
                toggleRow(
                    icon: "bolt.fill",
                    title: "Launch at Startup",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                toggleRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback (Clicks)",
                    isOn: $settings.hapticsEnabled
                )

                toggleRow(
                    icon: "tv.fill",
                    title: "HUD Volume Popup",
                    isOn: $settings.showHUD
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            Divider().opacity(0.5)

            // MARK: - Minimal Footer
            footerView
                .padding(.bottom, 2)
        }
        .padding(16)
        .frame(width: 380)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MacGesture Control")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                HStack(spacing: 5) {
                    Circle()
                        .fill(settings.isEnabled ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(settings.isEnabled ? "Active & Listening" : "Paused")
                        .font(.system(size: 11))
                        .foregroundColor(settings.isEnabled ? .green : .secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
        }
    }

    // MARK: - Gesture Row
    private func gestureRow(id: String, icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        let isFlashing = engine.lastTriggeredGestureId == id
        let isAssigned = binding.wrappedValue != .none

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Menu {
                ForEach(GestureAction.allCases) { action in
                    Button(action: {
                        binding.wrappedValue = action
                        HapticManager.shared.trigger()
                    }) {
                        HStack {
                            Label(action.title, systemImage: action.icon)
                            if binding.wrappedValue == action {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: binding.wrappedValue.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(binding.wrappedValue.shortTitle)
                        .font(.system(size: 11, weight: isAssigned ? .semibold : .regular))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isAssigned ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isAssigned ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                )
                .foregroundColor(isAssigned ? .accentColor : .secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.25) : (isAssigned ? Color.primary.opacity(0.03) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFlashing ? Color.accentColor : Color.primary.opacity(0.05), lineWidth: isFlashing ? 1.5 : 0.8)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    // MARK: - Toggle Row
    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11))

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .scaleEffect(0.8)
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/ImTheCloud/MacGestureControl")!) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 9))
                    Text("GitHub")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                settings.resetToDefaults()
                HUDManager.shared.show(icon: "arrow.counterclockwise", title: "Reset to Defaults")
                HapticManager.shared.triggerClick()
            }) {
                Text("Reset")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Text("•").foregroundColor(.secondary).font(.system(size: 8))

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}

// Background Visual Effect for macOS vibrancy
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
