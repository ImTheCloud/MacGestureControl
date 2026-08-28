// SettingsView.swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = MultitouchEngine.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var permissions = PermissionMonitor.shared

    @State private var selectedTab: Tab = .dashboard

    private enum Tab: Hashable {
        case dashboard
        case group(GestureGroup)

        var title: String {
            switch self {
            case .dashboard: return "Active"
            case .group(let group): return group.tabTitle
            }
        }
    }

    private let tabs: [Tab] = [.dashboard] + GestureGroup.allCases.map(Tab.group)

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider().opacity(0.4)

            tabBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider().opacity(0.4)

            ScrollView {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .dashboard: dashboard
                    case .group(let group): groupSection(group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: 330)

            Divider().opacity(0.4)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
        }
        .frame(width: 410)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.85)
        }
    }

    private var statusColor: Color {
        guard settings.isEnabled else { return .secondary }
        return permissions.isTrusted ? .green : .orange
    }

    private var statusText: String {
        guard settings.isEnabled else { return "Paused" }
        return permissions.isTrusted ? "Active & listening" : "Waiting for permission"
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(tabs, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    private func tabItem(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
            HapticManager.shared.trigger()
        } label: {
            Text(tab.title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        VStack(spacing: 12) {
            if !permissions.isTrusted {
                permissionBanner
            }

            activeGestures
            TouchVisualizerView()
            preferences
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility access required")
                    .font(.system(size: 11, weight: .semibold))
                Text("Gestures cannot control your Mac until it is granted.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 6)

            Button("Open") { permissions.openSettings() }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 0.8)
                )
        )
    }

    private var activeGestures: some View {
        let assigned = settings.assignedSlots

        return VStack(spacing: 0) {
            sectionHeader(icon: "bolt.fill", text: "ACTIVE GESTURES")

            VStack(spacing: 0) {
                if assigned.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("No gestures assigned yet — pick one from a tab above.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                } else {
                    ForEach(Array(assigned.enumerated()), id: \.element) { index, slot in
                        if index > 0 { rowDivider }
                        gestureRow(slot, showsSlotName: true)
                    }
                }
            }
            .background(cardBackground)
        }
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "gearshape.fill", text: "PREFERENCES")

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
                toggleRow(icon: "hand.tap.fill", title: "Haptic Feedback", isOn: $settings.hapticsEnabled)
                rowDivider
                toggleRow(icon: "macwindow.on.rectangle", title: "On-Screen HUD", isOn: $settings.showHUD)
                rowDivider
                toggleRow(icon: "arrow.up.arrow.down", title: "Invert Swipe Direction", isOn: $settings.invertDirection)
                rowDivider
                sensitivityRow
                rowDivider
                menuBarIconRow

                if settings.usesLaunchApp {
                    rowDivider
                    launchTargetRow
                }
            }
            .background(cardBackground)
        }
    }

    private var sensitivityRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "dial.medium.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Text("Sensitivity")
                .font(.system(size: 11))

            Spacer(minLength: 8)

            Slider(value: $settings.sensitivity, in: 0...1)
                .controlSize(.mini)
                .frame(width: 120)

            Text(sensitivityLabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var sensitivityLabel: String {
        switch settings.sensitivity {
        case ..<0.34: return "Low"
        case ..<0.67: return "Medium"
        default: return "High"
        }
    }

    private var menuBarIconRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Text("Menu Bar Icon")
                .font(.system(size: 11))

            Spacer()

            HStack(spacing: 4) {
                ForEach(AppSettings.menuBarIconChoices, id: \.self) { icon in
                    Button {
                        settings.menuBarIcon = icon
                        HapticManager.shared.trigger()
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(settings.menuBarIcon == icon
                                          ? Color.accentColor.opacity(0.20)
                                          : Color.primary.opacity(0.05))
                            )
                            .foregroundColor(settings.menuBarIcon == icon ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var launchTargetRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Text("Launch Target")
                .font(.system(size: 11))

            Spacer(minLength: 6)

            Button {
                chooseLaunchTarget()
            } label: {
                HStack(spacing: 4) {
                    Text(launchTargetName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "folder")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .frame(width: 118, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8)
                        )
                )
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var launchTargetName: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settings.launchTargetBundleId) else {
            return "Choose…"
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func chooseLaunchTarget() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"

        // Accessory apps are not frontmost, so the panel needs an explicit nudge.
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleId = Bundle(url: url)?.bundleIdentifier else { return }
        settings.launchTargetBundleId = bundleId
    }

    // MARK: - Gesture tabs

    private func groupSection(_ group: GestureGroup) -> some View {
        VStack(spacing: 0) {
            sectionHeader(icon: group.sectionIcon, text: group.sectionTitle)

            VStack(spacing: 0) {
                ForEach(Array(group.slots.enumerated()), id: \.element) { index, slot in
                    if index > 0 { rowDivider }
                    gestureRow(slot, showsSlotName: false)
                }
            }
            .background(cardBackground)
        }
    }

    // MARK: - Rows

    private func gestureRow(_ slot: GestureSlot, showsSlotName: Bool) -> some View {
        let action = settings.action(for: slot)
        let isAssigned = action != .none
        let isFlashing = engine.lastTriggeredSlot == slot

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 26, height: 26)
                Image(systemName: slot.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(showsSlotName ? slot.fullTitle : slot.title)
                    .font(.system(size: 11.5, weight: .medium))
                Text(description(for: slot, action: action))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            actionPicker(for: slot, action: action)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.22) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    /// Describes what the gesture actually does now, including the reverse
    /// direction of a swipe, instead of a hard-coded caption.
    private func description(for slot: GestureSlot, action: GestureAction) -> String {
        guard action != .none else { return slot.subtitle }

        let isSwipe = slot.kind == .swipeVertical || slot.kind == .swipeHorizontal
        guard isSwipe else { return action.title }

        if action.isContinuous {
            return slot.kind == .swipeVertical ? "Up raises · down lowers" : "Right raises · left lowers"
        }
        guard action.hasDistinctInverse else { return action.title }

        let forward = slot.kind == .swipeVertical ? "Up" : "Right"
        let backward = slot.kind == .swipeVertical ? "Down" : "Left"
        return "\(forward): \(action.shortTitle) · \(backward): \(action.inverse.shortTitle)"
    }

    private func actionPicker(for slot: GestureSlot, action: GestureAction) -> some View {
        let isAssigned = action != .none

        return Menu {
            Button {
                settings.setAction(.none, for: slot)
                HapticManager.shared.trigger()
            } label: {
                Label(GestureAction.none.title, systemImage: GestureAction.none.icon)
            }

            ForEach(ActionCategory.allCases) { category in
                let options = GestureAction.allCases.filter { $0 != .none && $0.category == category }
                if !options.isEmpty {
                    Section(category.rawValue) {
                        ForEach(options) { option in
                            Button {
                                settings.setAction(option, for: slot)
                                HapticManager.shared.trigger()
                            } label: {
                                Label(option.title, systemImage: option.icon)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(action.shortTitle)
                    .font(.system(size: 10, weight: isAssigned ? .semibold : .regular))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
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
        .menuIndicator(.hidden)
        .fixedSize()
    }

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
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Shared chrome

    private func sectionHeader(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
        }
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

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/ImTheCloud/MacGestureControl")!) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text("GitHub")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                settings.resetToDefaults()
                HUDManager.shared.show(icon: "arrow.counterclockwise", title: "Reset to Defaults")
                HapticManager.shared.triggerClick()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8))
                    Text("Reset Defaults")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Text("•")
                .font(.system(size: 8))
                .foregroundColor(.secondary)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "power")
                        .font(.system(size: 8))
                    Text("Quit")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

/// macOS vibrancy behind the popover.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
