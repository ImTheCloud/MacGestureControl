// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var engine = MultitouchEngine.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().opacity(0.5)

            // MARK: - Navigation Tabs Bar (5 Distinct Tabs)
            navigationTabsBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider().opacity(0.4)

            // MARK: - Main Tab Content
            ScrollView(showsIndicators: true) {
                VStack(spacing: 8) {
                    switch selectedTab {
                    case 0:
                        activeDashboardSection
                    case 1:
                        fourFingerSection
                    case 2:
                        threeFingerSection
                    case 3:
                        twoFingerSection
                    case 4:
                        cornersSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 310)

            Divider().opacity(0.5)

            // MARK: - Footer
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 410)
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

    // MARK: - Navigation Tabs Bar (5 Equal Responsive Buttons)
    private var navigationTabsBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Active", icon: "bolt.fill", index: 0)
            tabButton(title: "4-Finger", icon: "hand.raised.fill", index: 1)
            tabButton(title: "3-Finger", icon: "hand.point.up.left.and.right", index: 2)
            tabButton(title: "2-Finger", icon: "hand.point.up.2.fill", index: 3)
            tabButton(title: "Corners", icon: "square.grid.2x2.fill", index: 4)
        }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
            HapticManager.shared.trigger()
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(selectedTab == index ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(selectedTab == index ? .accentColor : .primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 0: Active Dashboard (Default View with Settings)
    private var activeDashboardSection: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ENABLED GESTURES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                // 4-Finger Vertical (Volume default)
                if settings.fourFingerVerticalAction != .none {
                    gestureRow(
                        id: "fourFingerVertical",
                        icon: "speaker.wave.3.fill",
                        title: "4-Finger Swipe",
                        subtitle: "System Volume control",
                        binding: $settings.fourFingerVerticalAction
                    )
                }

                // 4-Finger Tap (Play/Pause default)
                if settings.fourFingerTapAction != .none {
                    gestureRow(
                        id: "fourFingerTap",
                        icon: "playpause.fill",
                        title: "4-Finger Tap",
                        subtitle: "Play / Pause (Spotify, Music)",
                        binding: $settings.fourFingerTapAction
                    )
                }

                // 3-Finger Tap (Screenshot default)
                if settings.threeFingerTapAction != .none {
                    gestureRow(
                        id: "threeFingerTap",
                        icon: "camera.fill",
                        title: "3-Finger Tap",
                        subtitle: "Instant Screenshot (Cmd+Shift+4)",
                        binding: $settings.threeFingerTapAction
                    )
                }

                // Other dynamically enabled gestures
                if settings.threeFingerHorizontalAction != .none {
                    gestureRow(id: "threeFingerHorizontal", icon: "arrow.left.and.right", title: "3-Finger Swipe", subtitle: "Slide left / right", binding: $settings.threeFingerHorizontalAction)
                }
                if settings.twoFingerTapAction != .none {
                    gestureRow(id: "twoFingerTap", icon: "hand.tap.fill", title: "2-Finger Tap", subtitle: "Secondary tap action", binding: $settings.twoFingerTapAction)
                }
                if settings.cornerTopLeftAction != .none {
                    gestureRow(id: "cornerTopLeft", icon: "square.topthird.inset.filled", title: "Top-Left Corner", subtitle: "Corner trigger", binding: $settings.cornerTopLeftAction)
                }
            }

            Divider().opacity(0.4)

            // Essential Settings Toggles (Standard macOS Terminology)
            VStack(spacing: 6) {
                toggleRow(
                    icon: "bolt.fill",
                    title: "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                toggleRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback (Taptic Engine)",
                    isOn: $settings.hapticsEnabled
                )

                toggleRow(
                    icon: "macwindow.on.rectangle",
                    title: "On-Screen HUD Overlay",
                    isOn: $settings.showHUD
                )
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Tab 1: 4-Finger Section
    private var fourFingerSection: some View {
        VStack(spacing: 7) {
            gestureRow(
                id: "fourFingerVertical",
                icon: "arrow.up.and.down",
                title: "4-Finger Vertical Swipe",
                subtitle: "Default: Adjust System Volume",
                binding: $settings.fourFingerVerticalAction
            )

            gestureRow(
                id: "fourFingerTap",
                icon: "hand.tap.fill",
                title: "4-Finger Single Tap",
                subtitle: "Default: Play / Pause Media",
                binding: $settings.fourFingerTapAction
            )

            gestureRow(
                id: "fourFingerHorizontal",
                icon: "arrow.left.and.right",
                title: "4-Finger Horizontal Swipe",
                subtitle: "Swipe left / right on trackpad",
                binding: $settings.fourFingerHorizontalAction
            )

            gestureRow(
                id: "fourFingerPinchIn",
                icon: "arrow.down.right.and.arrow.up.left",
                title: "4-Finger Pinch In",
                subtitle: "Pinch fingers closer together",
                binding: $settings.fourFingerPinchInAction
            )

            gestureRow(
                id: "fourFingerPinchOut",
                icon: "arrow.up.left.and.arrow.down.right",
                title: "4-Finger Spread Out",
                subtitle: "Spread fingers apart",
                binding: $settings.fourFingerPinchOutAction
            )
        }
    }

    // MARK: - Tab 2: 3-Finger Section
    private var threeFingerSection: some View {
        VStack(spacing: 7) {
            gestureRow(
                id: "threeFingerTap",
                icon: "camera.fill",
                title: "3-Finger Single Tap",
                subtitle: "Default: Take Screenshot",
                binding: $settings.threeFingerTapAction
            )

            gestureRow(
                id: "threeFingerHorizontal",
                icon: "arrow.left.and.right",
                title: "3-Finger Horizontal Swipe",
                subtitle: "Swipe left / right with 3 fingers",
                binding: $settings.threeFingerHorizontalAction
            )

            gestureRow(
                id: "threeFingerVertical",
                icon: "arrow.up.and.down",
                title: "3-Finger Vertical Swipe",
                subtitle: "Swipe up / down with 3 fingers",
                binding: $settings.threeFingerVerticalAction
            )

            gestureRow(
                id: "threeFingerPinchIn",
                icon: "arrow.down.right.and.arrow.up.left",
                title: "3-Finger Pinch In",
                subtitle: "Pinch in with 3 fingers",
                binding: $settings.threeFingerPinchInAction
            )

            gestureRow(
                id: "threeFingerPinchOut",
                icon: "arrow.up.left.and.arrow.down.right",
                title: "3-Finger Spread Out",
                subtitle: "Spread out with 3 fingers",
                binding: $settings.threeFingerPinchOutAction
            )
        }
    }

    // MARK: - Tab 3: 2-Finger Section
    private var twoFingerSection: some View {
        VStack(spacing: 7) {
            Text("2-Finger gestures (Disabled by default to protect browser scroll)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            gestureRow(
                id: "twoFingerTap",
                icon: "hand.tap.fill",
                title: "2-Finger Quick Tap",
                subtitle: "Tap with 2 fingers simultaneously",
                binding: $settings.twoFingerTapAction
            )

            gestureRow(
                id: "twoFingerVertical",
                icon: "arrow.up.and.down",
                title: "2-Finger Vertical Scroll Override",
                subtitle: "Overrides normal macOS page scrolling",
                binding: $settings.twoFingerVerticalAction
            )

            gestureRow(
                id: "twoFingerHorizontal",
                icon: "arrow.left.and.right",
                title: "2-Finger Horizontal Scroll Override",
                subtitle: "Overrides normal horizontal scrolling",
                binding: $settings.twoFingerHorizontalAction
            )
        }
    }

    // MARK: - Tab 4: Corner Taps Section
    private var cornersSection: some View {
        VStack(spacing: 7) {
            Text("Single-finger taps in trackpad corners")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            gestureRow(
                id: "cornerTopLeft",
                icon: "square.topthird.inset.filled",
                title: "Top-Left Corner Tap",
                subtitle: "Tap upper-left corner of trackpad",
                binding: $settings.cornerTopLeftAction
            )

            gestureRow(
                id: "cornerTopRight",
                icon: "square.trailingthird.inset.filled",
                title: "Top-Right Corner Tap",
                subtitle: "Tap upper-right corner of trackpad",
                binding: $settings.cornerTopRightAction
            )

            gestureRow(
                id: "cornerBottomLeft",
                icon: "square.bottomthird.inset.filled",
                title: "Bottom-Left Corner Tap",
                subtitle: "Tap lower-left corner of trackpad",
                binding: $settings.cornerBottomLeftAction
            )

            gestureRow(
                id: "cornerBottomRight",
                icon: "square.trailingthird.inset.filled",
                title: "Bottom-Right Corner Tap",
                subtitle: "Tap lower-right corner of trackpad",
                binding: $settings.cornerBottomRightAction
            )
        }
    }

    // MARK: - Gesture Row Component
    private func gestureRow(id: String, icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        let isFlashing = engine.lastTriggeredGestureId == id
        let isAssigned = binding.wrappedValue != .none

        return HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

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
                HStack(spacing: 4) {
                    Image(systemName: binding.wrappedValue.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(binding.wrappedValue.shortTitle)
                        .font(.system(size: 10, weight: isAssigned ? .semibold : .regular))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.25) : (isAssigned ? Color.primary.opacity(0.03) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isFlashing ? Color.accentColor : Color.primary.opacity(0.05), lineWidth: isFlashing ? 1.5 : 0.8)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    // MARK: - Toggle Row Component
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
                .scaleEffect(0.75)
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
                Text("Reset Defaults")
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
