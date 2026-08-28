// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedTab = 0
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Tab Bar
            Picker("", selection: $selectedTab) {
                Text("🖐️ 4 Fingers").tag(0)
                Text("🤟 3 Fingers").tag(1)
                Text("✌️ 2 Fingers").tag(2)
                Text("🎯 Corners").tag(3)
                Text("⚙️ General").tag(4)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Content Area
            ScrollView {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case 0:
                        fourFingersTab
                    case 1:
                        threeFingersTab
                    case 2:
                        twoFingersTab
                    case 3:
                        cornersTab
                    case 4:
                        generalTab
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(height: 380)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 390)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .shadow(color: .purple.opacity(0.35), radius: 6, x: 0, y: 3)
                Image(systemName: settings.menuBarIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("MacGesture Control")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("PRO")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundColor(.blue)
                }

                Text(settings.isEnabled ? "Gestures Active & Listening" : "Gestures Paused")
                    .font(.caption)
                    .foregroundColor(settings.isEnabled ? .green : .secondary)
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 4-Finger Tab
    private var fourFingersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Default Notice Banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("4-Finger Vertical Swipe is enabled by default for Volume.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)

            gestureCard(
                icon: "arrow.up.and.down",
                title: "4-Finger Vertical Swipe",
                subtitle: "Swipe up or down with 4 fingers",
                binding: $settings.fourFingerVerticalAction
            )

            gestureCard(
                icon: "arrow.left.and.right",
                title: "4-Finger Horizontal Swipe",
                subtitle: "Swipe left or right with 4 fingers",
                binding: $settings.fourFingerHorizontalAction
            )

            gestureCard(
                icon: "hand.tap.fill",
                title: "4-Finger Quick Tap",
                subtitle: "Brief 4-finger tap on trackpad",
                binding: $settings.fourFingerTapAction
            )

            gestureCard(
                icon: "arrow.down.right.and.arrow.up.left",
                title: "4-Finger Pinch In",
                subtitle: "Pinch in with 4 fingers",
                binding: $settings.fourFingerPinchInAction
            )

            gestureCard(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "4-Finger Spread Out",
                subtitle: "Spread out with 4 fingers",
                binding: $settings.fourFingerPinchOutAction
            )
        }
    }

    // MARK: - 3-Finger Tab
    private var threeFingersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            gestureCard(
                icon: "hand.tap.fill",
                title: "3-Finger Quick Tap",
                subtitle: "Tip: Set to Middle Click for web browsing & CAD!",
                binding: $settings.threeFingerTapAction
            )

            gestureCard(
                icon: "arrow.up.and.down",
                title: "3-Finger Vertical Swipe",
                subtitle: "Swipe up or down with 3 fingers",
                binding: $settings.threeFingerVerticalAction
            )

            gestureCard(
                icon: "arrow.left.and.right",
                title: "3-Finger Horizontal Swipe",
                subtitle: "Swipe left or right with 3 fingers",
                binding: $settings.threeFingerHorizontalAction
            )

            gestureCard(
                icon: "arrow.down.right.and.arrow.up.left",
                title: "3-Finger Pinch In",
                subtitle: "Pinch in with 3 fingers",
                binding: $settings.threeFingerPinchInAction
            )

            gestureCard(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "3-Finger Spread Out",
                subtitle: "Spread out with 3 fingers",
                binding: $settings.threeFingerPinchOutAction
            )
        }
    }

    // MARK: - 2-Finger Tab
    private var twoFingersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Disabled by default to protect native macOS scrolling.")
                .font(.caption2)
                .foregroundColor(.secondary)

            gestureCard(
                icon: "hand.tap.fill",
                title: "2-Finger Quick Tap",
                subtitle: "Tap trackpad with 2 fingers",
                binding: $settings.twoFingerTapAction
            )

            gestureCard(
                icon: "arrow.up.and.down",
                title: "2-Finger Vertical Scroll Override",
                subtitle: "Replaces standard vertical scrolling with an action",
                binding: $settings.twoFingerVerticalAction
            )

            gestureCard(
                icon: "arrow.left.and.right",
                title: "2-Finger Horizontal Scroll Override",
                subtitle: "Replaces standard horizontal scrolling with an action",
                binding: $settings.twoFingerHorizontalAction
            )
        }
    }

    // MARK: - Corners & Snapping Tab
    private var cornersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Single-finger taps in trackpad corners:")
                .font(.caption)
                .foregroundColor(.secondary)

            gestureCard(
                icon: "square.topthird.inset.filled",
                title: "Top-Left Corner Tap",
                subtitle: "Tap upper-left corner of trackpad",
                binding: $settings.cornerTopLeftAction
            )

            gestureCard(
                icon: "square.trailingthird.inset.filled",
                title: "Top-Right Corner Tap",
                subtitle: "Tap upper-right corner of trackpad",
                binding: $settings.cornerTopRightAction
            )

            gestureCard(
                icon: "square.bottomthird.inset.filled",
                title: "Bottom-Left Corner Tap",
                subtitle: "Tap lower-left corner of trackpad",
                binding: $settings.cornerBottomLeftAction
            )

            gestureCard(
                icon: "square.trailingthird.inset.filled",
                title: "Bottom-Right Corner Tap",
                subtitle: "Tap lower-right corner of trackpad",
                binding: $settings.cornerBottomRightAction
            )

            // Quick Window Snap Test Actions
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Window Snap Test:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Button(action: { WindowManager.shared.snapActiveWindow(to: .snapLeft) }) {
                        Label("Left Half", systemImage: "rectangle.lefthalf.filled")
                    }.buttonStyle(.bordered).font(.caption2)

                    Button(action: { WindowManager.shared.snapActiveWindow(to: .snapRight) }) {
                        Label("Right Half", systemImage: "rectangle.righthalf.filled")
                    }.buttonStyle(.bordered).font(.caption2)

                    Button(action: { WindowManager.shared.snapActiveWindow(to: .maximizeWindow) }) {
                        Label("Maximize", systemImage: "arrow.up.left.and.arrow.down.right")
                    }.buttonStyle(.bordered).font(.caption2)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
    }

    // MARK: - General Tab
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Live Touch Radar
            TouchVisualizerView()

            // Custom Launch App ID
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom App Bundle ID (for 'Launch Application' action):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("com.apple.Notes, com.spotify.client, etc.", text: $settings.targetBundleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Sensitivity Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Gesture Swipe Sensitivity", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", settings.sensitivity * 1000))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                Slider(value: $settings.sensitivity, in: 0.01...0.15, step: 0.01)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Toggles
            VStack(spacing: 8) {
                Toggle("Haptic Feedback (Taptic Engine clicks)", isOn: $settings.hapticsEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .font(.caption)

                Toggle("On-Screen Dynamic HUD Overlay", isOn: $settings.showHUD)
                    .toggleStyle(SwitchToggleStyle())
                    .font(.caption)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Menu Bar Icon Picker
            HStack {
                Text("Menu Bar Icon:")
                    .font(.caption)
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
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Permissions Status Card
            HStack(spacing: 10) {
                Image(systemName: isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isAccessibilityGranted ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isAccessibilityGranted ? "Accessibility Permission: Granted" : "Permission Required")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(isAccessibilityGranted ? "Input monitoring is active." : "Enable in System Settings -> Privacy & Security.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isAccessibilityGranted {
                    Button("Open") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Reset Defaults Button
            Button(action: {
                settings.resetToDefaults()
                HUDManager.shared.show(icon: "arrow.counterclockwise", title: "Reset to Defaults")
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All Gestures to Defaults")
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Reusable Card
    private func gestureCard(icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Picker("", selection: binding) {
                ForEach(GestureAction.allCases) { action in
                    Label(action.title, systemImage: action.icon).tag(action)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/ImTheCloud/MacGestureControl")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                    Text("GitHub")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
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
                .font(.caption)
                .fontWeight(.medium)
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

