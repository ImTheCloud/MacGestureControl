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
                .padding(.bottom, 12)

            Divider().opacity(0.4)

            // MARK: - Unified Segmented Tab Bar
            segmentedTabBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider().opacity(0.4)

            // MARK: - Tab Content
            ScrollView(showsIndicators: true) {
                VStack(spacing: 12) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: 310)

            Divider().opacity(0.4)

            // MARK: - Footer
            footerView
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
        }
        .frame(width: 410)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MacGesture Control")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.isEnabled ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(settings.isEnabled ? "Active & Listening" : "Paused")
                        .font(.system(size: 10))
                        .foregroundColor(settings.isEnabled ? .green : .secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .scaleEffect(0.85)
        }
    }

    // MARK: - Unified Segmented Tab Bar
    private var segmentedTabBar: some View {
        HStack(spacing: 3) {
            tabItem(title: "Active", icon: "bolt.fill", index: 0)
            tabItem(title: "4-Finger", icon: "hand.raised.fill", index: 1)
            tabItem(title: "3-Finger", icon: "hand.point.up.left.and.right", index: 2)
            tabItem(title: "2-Finger", icon: "hand.point.up.2.fill", index: 3)
            tabItem(title: "Corners", icon: "square.grid.2x2.fill", index: 4)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func tabItem(title: String, icon: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
            HapticManager.shared.trigger()
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: selectedTab == index ? .bold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
            .foregroundColor(selectedTab == index ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 0: Active Dashboard
    private var activeDashboardSection: some View {
        VStack(spacing: 12) {
            // Enabled Gestures Inset Group
            VStack(spacing: 0) {
                headerLabel("ACTIVE GESTURES")

                VStack(spacing: 0) {
                    if settings.fourFingerVerticalAction != .none {
                        gestureRow(
                            id: "fourFingerVertical",
                            icon: "speaker.wave.3.fill",
                            title: "4-Finger Swipe",
                            subtitle: "System Volume control",
                            binding: $settings.fourFingerVerticalAction
                        )
                    }

                    if settings.fourFingerTapAction != .none {
                        if settings.fourFingerVerticalAction != .none { rowDivider }
                        gestureRow(
                            id: "fourFingerTap",
                            icon: "playpause.fill",
                            title: "4-Finger Tap",
                            subtitle: "Play / Pause (Spotify, Music)",
                            binding: $settings.fourFingerTapAction
                        )
                    }

                    if settings.threeFingerTapAction != .none {
                        if settings.fourFingerVerticalAction != .none || settings.fourFingerTapAction != .none { rowDivider }
                        gestureRow(
                            id: "threeFingerTap",
                            icon: "camera.fill",
                            title: "3-Finger Tap",
                            subtitle: "Instant Screenshot (Cmd+Shift+4)",
                            binding: $settings.threeFingerTapAction
                        )
                    }

                    if settings.threeFingerHorizontalAction != .none {
                        rowDivider
                        gestureRow(id: "threeFingerHorizontal", icon: "arrow.left.and.right", title: "3-Finger Swipe", subtitle: "Slide left / right", binding: $settings.threeFingerHorizontalAction)
                    }
                    if settings.twoFingerTapAction != .none {
                        rowDivider
                        gestureRow(id: "twoFingerTap", icon: "hand.tap.fill", title: "2-Finger Tap", subtitle: "Secondary tap action", binding: $settings.twoFingerTapAction)
                    }
                    if settings.cornerTopLeftAction != .none {
                        rowDivider
                        gestureRow(id: "cornerTopLeft", icon: "square.topthird.inset.filled", title: "Top-Left Corner", subtitle: "Corner trigger", binding: $settings.cornerTopLeftAction)
                    }
                }
                .background(cardBackground)
            }

            // System Options Inset Group
            VStack(spacing: 0) {
                headerLabel("PREFERENCES")

                VStack(spacing: 0) {
                    toggleRow(
                        icon: "bolt.fill",
                        title: "Launch at Login",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )

                    rowDivider

                    toggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Haptic Feedback (Taptic Engine)",
                        isOn: $settings.hapticsEnabled
                    )

                    rowDivider

                    toggleRow(
                        icon: "macwindow.on.rectangle",
                        title: "On-Screen HUD Overlay",
                        isOn: $settings.showHUD
                    )
                }
                .background(cardBackground)
            }
        }
    }

    // MARK: - Tab 1: 4-Finger Section
    private var fourFingerSection: some View {
        VStack(spacing: 0) {
            headerLabel("4-FINGER GESTURES")

            VStack(spacing: 0) {
                gestureRow(
                    id: "fourFingerVertical",
                    icon: "arrow.up.and.down",
                    title: "Vertical Swipe",
                    subtitle: "Slide up or down on trackpad",
                    binding: $settings.fourFingerVerticalAction
                )

                rowDivider

                gestureRow(
                    id: "fourFingerTap",
                    icon: "hand.tap.fill",
                    title: "Single Tap",
                    subtitle: "Brief tap with 4 fingers",
                    binding: $settings.fourFingerTapAction
                )

                rowDivider

                gestureRow(
                    id: "fourFingerHorizontal",
                    icon: "arrow.left.and.right",
                    title: "Horizontal Swipe",
                    subtitle: "Slide left or right on trackpad",
                    binding: $settings.fourFingerHorizontalAction
                )

                rowDivider

                gestureRow(
                    id: "fourFingerPinchIn",
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "Pinch In",
                    subtitle: "Pinch fingers closer together",
                    binding: $settings.fourFingerPinchInAction
                )

                rowDivider

                gestureRow(
                    id: "fourFingerPinchOut",
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Spread Out",
                    subtitle: "Spread fingers apart",
                    binding: $settings.fourFingerPinchOutAction
                )
            }
            .background(cardBackground)
        }
    }

    // MARK: - Tab 2: 3-Finger Section
    private var threeFingerSection: some View {
        VStack(spacing: 0) {
            headerLabel("3-FINGER GESTURES")

            VStack(spacing: 0) {
                gestureRow(
                    id: "threeFingerTap",
                    icon: "camera.fill",
                    title: "Single Tap",
                    subtitle: "Brief tap with 3 fingers",
                    binding: $settings.threeFingerTapAction
                )

                rowDivider

                gestureRow(
                    id: "threeFingerHorizontal",
                    icon: "arrow.left.and.right",
                    title: "Horizontal Swipe",
                    subtitle: "Slide left or right with 3 fingers",
                    binding: $settings.threeFingerHorizontalAction
                )

                rowDivider

                gestureRow(
                    id: "threeFingerVertical",
                    icon: "arrow.up.and.down",
                    title: "Vertical Swipe",
                    subtitle: "Slide up or down with 3 fingers",
                    binding: $settings.threeFingerVerticalAction
                )

                rowDivider

                gestureRow(
                    id: "threeFingerPinchIn",
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "Pinch In",
                    subtitle: "Pinch in with 3 fingers",
                    binding: $settings.threeFingerPinchInAction
                )

                rowDivider

                gestureRow(
                    id: "threeFingerPinchOut",
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Spread Out",
                    subtitle: "Spread out with 3 fingers",
                    binding: $settings.threeFingerPinchOutAction
                )
            }
            .background(cardBackground)
        }
    }

    // MARK: - Tab 3: 2-Finger Section
    private var twoFingerSection: some View {
        VStack(spacing: 0) {
            headerLabel("2-FINGER GESTURES")

            VStack(spacing: 0) {
                gestureRow(
                    id: "twoFingerTap",
                    icon: "hand.tap.fill",
                    title: "Single Tap",
                    subtitle: "Tap with 2 fingers simultaneously",
                    binding: $settings.twoFingerTapAction
                )

                rowDivider

                gestureRow(
                    id: "twoFingerVertical",
                    icon: "arrow.up.and.down",
                    title: "Vertical Scroll Override",
                    subtitle: "Overrides macOS web scrolling",
                    binding: $settings.twoFingerVerticalAction
                )

                rowDivider

                gestureRow(
                    id: "twoFingerHorizontal",
                    icon: "arrow.left.and.right",
                    title: "Horizontal Scroll Override",
                    subtitle: "Overrides horizontal scrolling",
                    binding: $settings.twoFingerHorizontalAction
                )
            }
            .background(cardBackground)
        }
    }

    // MARK: - Tab 4: Corner Taps Section
    private var cornersSection: some View {
        VStack(spacing: 0) {
            headerLabel("CORNER TAPS")

            VStack(spacing: 0) {
                gestureRow(
                    id: "cornerTopLeft",
                    icon: "square.topthird.inset.filled",
                    title: "Top-Left Corner",
                    subtitle: "Tap top-left corner of trackpad",
                    binding: $settings.cornerTopLeftAction
                )

                rowDivider

                gestureRow(
                    id: "cornerTopRight",
                    icon: "square.trailingthird.inset.filled",
                    title: "Top-Right Corner",
                    subtitle: "Tap top-right corner of trackpad",
                    binding: $settings.cornerTopRightAction
                )

                rowDivider

                gestureRow(
                    id: "cornerBottomLeft",
                    icon: "square.bottomthird.inset.filled",
                    title: "Bottom-Left Corner",
                    subtitle: "Tap bottom-left corner of trackpad",
                    binding: $settings.cornerBottomLeftAction
                )

                rowDivider

                gestureRow(
                    id: "cornerBottomRight",
                    icon: "square.trailingthird.inset.filled",
                    title: "Bottom-Right Corner",
                    subtitle: "Tap bottom-right corner of trackpad",
                    binding: $settings.cornerBottomRightAction
                )
            }
            .background(cardBackground)
        }
    }

    // MARK: - Reusable UI Helpers
    private func headerLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 5)
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.3)
            .padding(.leading, 42)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.8)
            )
    }

    // MARK: - Gesture Row Component
    private func gestureRow(id: String, icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        let isFlashing = engine.lastTriggeredGestureId == id
        let isAssigned = binding.wrappedValue != .none

        return HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // Right Action Menu Button (Consistent 118pt width)
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
                .frame(width: 118, alignment: .trailing)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.22) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    // MARK: - Toggle Row Component
    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11))

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .scaleEffect(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
