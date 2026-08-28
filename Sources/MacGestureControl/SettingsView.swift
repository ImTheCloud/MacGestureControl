// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var engine = MultitouchEngine.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @State private var selectedTab: Int = 0
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
            
            Divider().opacity(0.6)

            // MARK: - Navigation Tabs (5 Clean, Distinct Tabs)
            navigationPillBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().opacity(0.4)

            // MARK: - Main Scrollable Content
            ScrollView(showsIndicators: true) {
                VStack(spacing: 8) {
                    switch selectedTab {
                    case 0:
                        fourFingerSection
                    case 1:
                        threeFingerSection
                    case 2:
                        twoFingerSection
                    case 3:
                        cornersSection
                    case 4:
                        preferencesSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 360)

            Divider().opacity(0.6)

            // MARK: - Footer
            footerView
        }
        .frame(width: 440)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.purple.opacity(0.35), radius: 5, x: 0, y: 2)

                Image(systemName: settings.menuBarIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("MacGesture Control")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    Text("v2.0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(settings.isEnabled ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(settings.isEnabled ? "Active & Listening" : "Gestures Paused")
                        .font(.system(size: 11))
                        .foregroundColor(settings.isEnabled ? .green : .secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Navigation Tabs Bar (5 Equal Responsive Buttons)
    private var navigationPillBar: some View {
        HStack(spacing: 5) {
            navPill(title: "4-Finger", icon: "hand.raised.fill", index: 0)
            navPill(title: "3-Finger", icon: "hand.point.up.left.and.right", index: 1)
            navPill(title: "2-Finger", icon: "hand.point.up.2.fill", index: 2)
            navPill(title: "Corners", icon: "square.grid.2x2.fill", index: 3)
            navPill(title: "Settings", icon: "gearshape.fill", index: 4)
        }
    }

    private func navPill(title: String, icon: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
            HapticManager.shared.trigger()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selectedTab == index ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(selectedTab == index ? .accentColor : .primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4-Finger Section
    private var fourFingerSection: some View {
        VStack(spacing: 8) {
            gestureRow(
                id: "fourFingerVertical",
                icon: "arrow.up.and.down",
                title: "4-Finger Vertical Swipe",
                subtitle: "Swipe up / down on trackpad (Default: Volume)",
                binding: $settings.fourFingerVerticalAction
            )

            gestureRow(
                id: "fourFingerTap",
                icon: "hand.tap.fill",
                title: "4-Finger Single Tap",
                subtitle: "Brief tap with 4 fingers (Default: Play/Pause)",
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

    // MARK: - 3-Finger Section
    private var threeFingerSection: some View {
        VStack(spacing: 8) {
            gestureRow(
                id: "threeFingerTap",
                icon: "camera.fill",
                title: "3-Finger Single Tap",
                subtitle: "Brief tap with 3 fingers (Default: Screenshot)",
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

    // MARK: - 2-Finger Section
    private var twoFingerSection: some View {
        VStack(spacing: 8) {
            Text("2-Finger gestures (Disabled by default to protect browser scroll)")
                .font(.system(size: 11, weight: .semibold))
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

    // MARK: - Corner Taps Section
    private var cornersSection: some View {
        VStack(spacing: 8) {
            Text("Single-finger taps in trackpad corners")
                .font(.system(size: 11, weight: .semibold))
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

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(spacing: 10) {
            // Live Radar Canvas
            TouchVisualizerView()

            // Custom Launch App ID
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Bundle ID (for 'Launch Application' action):")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g. com.apple.Notes, com.spotify.client", text: $settings.targetBundleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            // Sensitivity Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Gesture Swipe Sensitivity", systemImage: "speedometer")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", settings.sensitivity * 1000))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                Slider(value: $settings.sensitivity, in: 0.01...0.15, step: 0.01)
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            // Toggles
            VStack(spacing: 8) {
                Toggle("Launch at Login (Start automatically on boot)", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(SwitchToggleStyle())
                .font(.system(size: 11))

                Toggle("Haptic Feedback (Taptic Engine clicks)", isOn: $settings.hapticsEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .font(.system(size: 11))

                Toggle("On-Screen Dynamic HUD Overlay", isOn: $settings.showHUD)
                    .toggleStyle(SwitchToggleStyle())
                    .font(.system(size: 11))
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            // Menu Bar Icon Picker
            HStack {
                Text("Menu Bar Icon:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $settings.menuBarIcon) {
                    Label("Hand Wave", systemImage: "hand.draw.fill").tag("hand.draw.fill")
                    Label("Hand Tap", systemImage: "hand.tap.fill").tag("hand.tap.fill")
                    Label("Sliders", systemImage: "slider.horizontal.3").tag("slider.horizontal.3")
                    Label("Waveform", systemImage: "waveform").tag("waveform")
                    Label("Sparkles", systemImage: "sparkles").tag("sparkles")
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .onChange(of: settings.menuBarIcon) { newIcon in
                    AppDelegate.shared?.updateStatusItemIcon(newIcon)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            // Permissions Card
            HStack(spacing: 10) {
                Image(systemName: isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isAccessibilityGranted ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isAccessibilityGranted ? "Accessibility: Active" : "Accessibility: Required")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isAccessibilityGranted ? "Input monitoring is running smoothly." : "Grant permission in System Settings.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isAccessibilityGranted {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)

            // Reset Button
            Button(action: {
                settings.resetToDefaults()
                HUDManager.shared.show(icon: "arrow.counterclockwise", title: "Reset to Defaults")
                HapticManager.shared.triggerClick()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All Gestures to Defaults")
                }
                .font(.system(size: 11))
                .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Bespoke Gesture Row Component
    private func gestureRow(id: String, icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        let isFlashing = engine.lastTriggeredGestureId == id
        let isAssigned = binding.wrappedValue != .none

        return HStack(spacing: 10) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }

            // Title & Subtitle
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

            // Compact Inline Menu Button
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
                    Text(binding.wrappedValue == .none ? "Disabled" : binding.wrappedValue.title)
                        .font(.system(size: 11, weight: isAssigned ? .semibold : .regular))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: 175, alignment: .trailing)
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
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.2) : (isAssigned ? Color.primary.opacity(0.03) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFlashing ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isFlashing ? 1.5 : 0.8)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/ImTheCloud/MacGestureControl")!) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text("Star on GitHub")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .foregroundColor(.red)
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
