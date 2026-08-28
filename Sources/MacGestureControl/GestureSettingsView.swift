// GestureSettingsView.swift
import SwiftUI

struct GestureSettingsView: View {
    @ObservedObject var settings = GestureSettings.shared
    @State private var selectedTab = 2
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()

            // Segmented Picker for Tabs
            Picker("", selection: $selectedTab) {
                Text("✌️ 2 Doigts").tag(0)
                Text("🤟 3 Doigts").tag(1)
                Text("🖐️ 4 Doigts").tag(2)
                Text("⚙️ Options").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Tab Content
            ScrollView {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case 0:
                        twoFingersTab
                    case 1:
                        threeFingersTab
                    case 2:
                        fourFingersTab
                    case 3:
                        optionsTab
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 280)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 360)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MacGesture Control")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(settings.isEnabled ? "Contrôle gestuel actif" : "Contrôle désactivé")
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

    private var twoFingersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            gestureCard(
                icon: "arrow.up.and.down",
                title: "Défilement vertical (2 doigts)",
                subtitle: "Action au scroll haut / bas sur le trackpad",
                binding: $settings.twoFingerVerticalAction
            )

            gestureCard(
                icon: "arrow.left.and.right",
                title: "Défilement horizontal (2 doigts)",
                subtitle: "Action au scroll gauche / droite",
                binding: $settings.twoFingerHorizontalAction
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Sensibilité du défilement", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", settings.sensitivity * 1000))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Slider(value: $settings.sensitivity, in: 0.01...0.15, step: 0.01)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
    }

    private var threeFingersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            gestureCard(
                icon: "hand.point.up.left.and.right",
                title: "Balayage horizontal (3 doigts)",
                subtitle: "Glissement gauche / droite",
                binding: $settings.threeFingerHorizontalAction
            )

            gestureCard(
                icon: "hand.point.up.braille.fill",
                title: "Balayage vertical (3 doigts)",
                subtitle: "Glissement haut / bas",
                binding: $settings.threeFingerVerticalAction
            )
        }
    }

    private var fourFingersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            gestureCard(
                icon: "hand.raised.fill",
                title: "Balayage vertical (4 doigts)",
                subtitle: "Glissement vertical à 4 doigts",
                binding: $settings.fourFingerVerticalAction
            )

            gestureCard(
                icon: "hand.tap.fill",
                title: "Toucher à 4 doigts",
                subtitle: "Tap simultané à 4 doigts",
                binding: $settings.fourFingerTapAction
            )

            if settings.fourFingerTapAction == .launchApp || settings.fourFingerVerticalAction == .launchApp {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Identifiant Application (Bundle ID) :")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("ex: com.apple.Notes, com.spotify.client", text: $settings.targetBundleId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
            }
        }
    }

    private var optionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Accessibility Status Card
            HStack(spacing: 10) {
                Image(systemName: isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isAccessibilityGranted ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isAccessibilityGranted ? "Permission Accessibilité accordée" : "Permission requise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(isAccessibilityGranted ? "L'event tap fonctionne correctement." : "Activez l'accès dans Réglages Système.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isAccessibilityGranted {
                    Button("Ouvrir") {
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

            // Test actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Tester les actions :")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button(action: { AppDelegate.shared?.adjustSystemVolume(up: true) }) {
                        Label("Vol +", systemImage: "speaker.plus.fill")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    Button(action: { AppDelegate.shared?.adjustBrightness(up: true) }) {
                        Label("Lum +", systemImage: "sun.max.fill")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    Button(action: { AppDelegate.shared?.controlMedia(action: .playPause) }) {
                        Label("Play/Pause", systemImage: "playpause.fill")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
    }

    private func gestureCard(icon: String, title: String, subtitle: String, binding: Binding<GestureAction>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
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

    private var footerView: some View {
        HStack {
            Text("v1.0 • Open Source")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Quitter")
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// Background Visual Effect for macOS
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
