// SettingsView.swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// One set of row measurements for every card, so glyphs, labels and dividers
/// line up on the same axis whatever the row contains.
private enum Row {
    static let horizontalPadding: CGFloat = 11
    static let verticalPadding: CGFloat = 7
    static let glyphSize: CGFloat = 28
    static let glyphSpacing: CGFloat = 10
    static let controlWidth: CGFloat = 130
    /// Where every title starts, and where dividers are inset to.
    static var textInset: CGFloat { horizontalPadding + glyphSize + glyphSpacing }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = MultitouchEngine.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var permissions = PermissionMonitor.shared
    @ObservedObject private var nativeGestures = NativeGestureManager.shared
    @ObservedObject private var layout = PopoverLayout.shared

    @State private var selectedTab: Tab = .dashboard
    /// Height the current tab would like, measured from its content.
    @State private var naturalContentHeight: CGFloat = SettingsMetrics.minContentHeight

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

            ScrollView(.vertical) {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case .dashboard: dashboard
                    case .group(let group): groupSection(group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .frame(height: contentHeight)
            .scrollDisabled(!needsScrolling)
            .onPreferenceChange(ContentHeightKey.self) { measured in
                let rounded = measured.rounded()
                // Rounded and thresholded: the frame depends on this value, so a
                // jittering measurement would otherwise re-trigger layout forever.
                if abs(rounded - naturalContentHeight) > 0.5 { naturalContentHeight = rounded }
            }

            Divider().opacity(0.4)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: SettingsMetrics.width)
        // Vibrancy alone let a bright window behind the popover shine through
        // and wash the tinted controls out, so the blur sits on an opaque
        // ground: the frosted look survives, the contrast stops depending on
        // whatever happens to be on screen underneath.
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor).opacity(0.82)
            }
        )
    }

    /// The tab's own height, never shorter than a sliver and never taller than
    /// the screen allows.
    private var contentHeight: CGFloat {
        min(max(naturalContentHeight, SettingsMetrics.minContentHeight), layout.maxContentHeight)
    }

    private var needsScrolling: Bool {
        naturalContentHeight > layout.maxContentHeight
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                Image(systemName: AppSettings.appGlyph)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MacGesture Control")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusText)
                        .font(.system(size: 10.5))
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
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.vertical, 5.5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .secondary)
                // Without this only the text is hittable, not the padding
                // around it or the highlighted pill behind it.
                .contentShape(Rectangle())
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
            liveTrackpad
            preferences
        }
    }

    private var liveTrackpad: some View {
        let count = engine.activeTouches.count

        return VStack(spacing: 0) {
            sectionHeader(icon: "hand.point.up.left.fill", text: "LIVE TRACKPAD") {
                Text(count == 0 ? "Touch the trackpad" : "\(count) finger\(count == 1 ? "" : "s")")
                    .font(.system(size: 9.5, weight: count == 0 ? .regular : .bold, design: .rounded))
                    .foregroundColor(count == 0 ? .secondary : .accentColor)
            }
            TouchVisualizerView()
                .padding(10)
                .background(cardBackground)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: Row.glyphSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: Row.glyphSize)

            VStack(alignment: .leading, spacing: 1.5) {
                Text("Accessibility access required")
                    .font(.system(size: 12, weight: .semibold))
                Text(permissionDetail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Button("Open") { permissions.openSettings() }
                    .font(.system(size: 10.5, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                if !permissions.isBundled {
                    Button("Reveal") { permissions.revealExecutable() }
                        .font(.system(size: 10))
                        .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, Row.horizontalPadding)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 0.8)
                )
        )
    }

    /// An entry already switched on in System Settings is the confusing case,
    /// and it is the normal one for a binary run straight from `swift build`:
    /// the grant belongs to the build that asked for it, so the next build is a
    /// stranger to macOS even though the name in the list has not changed.
    private var permissionDetail: String {
        permissions.isBundled
            ? "Gestures cannot control your Mac until it is granted."
            : "Already switched on? That entry belongs to an earlier build of this binary. Remove it with – and add this one back."
    }

    private var activeGestures: some View {
        let assigned = settings.assignedSlots

        return VStack(spacing: 0) {
            sectionHeader(icon: "bolt.fill", text: "ACTIVE GESTURES")

            VStack(spacing: 0) {
                if assigned.isEmpty {
                    HStack(spacing: Row.glyphSpacing) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: Row.glyphSize)
                        Text("No gestures assigned yet — pick one from a tab above.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Row.horizontalPadding)
                    .padding(.vertical, 14)
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

                if nativeGestures.disabledCount > 0 {
                    rowDivider
                    settingRow(
                        icon: "arrow.uturn.backward",
                        title: "macOS gestures turned off (\(nativeGestures.disabledCount))"
                    ) {
                        Button("Restore") {
                            nativeGestures.restoreAll()
                            HapticManager.shared.triggerClick()
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.borderless)
                    }
                }

                if settings.usesMediaAction {
                    rowDivider
                    mediaTargetRow
                }

                if settings.usesLaunchApp {
                    rowDivider
                    launchTargetRow
                }
            }
            .background(cardBackground)
        }
    }

    private var sensitivityRow: some View {
        settingRow(icon: "dial.medium.fill", title: "Sensitivity") {
            HStack(spacing: 8) {
                Slider(value: $settings.sensitivity, in: 0...1)
                    .controlSize(.mini)
                Text(sensitivityLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
            .frame(width: Row.controlWidth)
        }
    }

    private var sensitivityLabel: String {
        switch settings.sensitivity {
        case ..<0.34: return "Low"
        case ..<0.67: return "Medium"
        default: return "High"
        }
    }

    /// Which app a media gesture wakes when nothing is playing — macOS answers
    /// that question with Music, and there is no system setting for it.
    private var mediaTargetRow: some View {
        settingRow(icon: "music.note.list", title: "Media App") {
            Menu {
                Button("System Default") { settings.mediaTargetBundleId = "" }
                ForEach(knownMediaApps, id: \.id) { app in
                    Button(app.name) { settings.mediaTargetBundleId = app.id }
                }
                Divider()
                Button("Choose…") { chooseMediaTarget() }
            } label: {
                HStack(spacing: 4) {
                    Text(mediaTargetName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: Row.controlWidth, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.20))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.55), lineWidth: 0.8)
                        )
                )
                .foregroundColor(.accentColor)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    /// The two players that answer a media command out of the box, when installed.
    private var knownMediaApps: [(id: String, name: String)] {
        [("com.spotify.client", "Spotify"), ("com.apple.Music", "Music")].filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.0) != nil
        }.map { (id: $0.0, name: $0.1) }
    }

    private var mediaTargetName: String {
        guard !settings.mediaTargetBundleId.isEmpty else { return "System Default" }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settings.mediaTargetBundleId) else {
            return "Choose…"
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func chooseMediaTarget() {
        guard let bundleId = chooseApplication() else { return }
        settings.mediaTargetBundleId = bundleId
    }

    private var launchTargetRow: some View {
        settingRow(icon: "arrow.up.forward.app.fill", title: "Launch Target") {
            Button {
                chooseLaunchTarget()
            } label: {
                HStack(spacing: 4) {
                    Text(launchTargetName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "folder")
                        .font(.system(size: 8.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: Row.controlWidth, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8)
                        )
                )
                .foregroundColor(.accentColor)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var launchTargetName: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settings.launchTargetBundleId) else {
            return "Choose…"
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func chooseLaunchTarget() {
        guard let bundleId = chooseApplication() else { return }
        settings.launchTargetBundleId = bundleId
    }

    /// Asks for an application and answers with its bundle identifier.
    private func chooseApplication() -> String? {
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
              let bundleId = Bundle(url: url)?.bundleIdentifier else { return nil }
        return bundleId
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
        VStack(spacing: 0) {
            gestureRowBody(slot, showsSlotName: showsSlotName)
            conflictNote(for: slot)
        }
    }

    private func gestureRowBody(_ slot: GestureSlot, showsSlotName: Bool) -> some View {
        let action = settings.action(for: slot)
        let isAssigned = action != .none
        let isFlashing = engine.lastTriggeredSlot == slot

        return HStack(spacing: Row.glyphSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isAssigned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                Image(systemName: slot.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAssigned ? .accentColor : .secondary)
            }
            .frame(width: Row.glyphSize, height: Row.glyphSize)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(showsSlotName ? slot.fullTitle : slot.title)
                    .font(.system(size: 12, weight: .medium))
                Text(description(for: slot, action: action))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            actionPicker(for: slot, action: action)
        }
        .padding(.horizontal, Row.horizontalPadding)
        .padding(.vertical, Row.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlashing ? Color.accentColor.opacity(0.22) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isFlashing)
    }

    /// macOS keeps its own trackpad gestures and we cannot consume the touch,
    /// so a bound slot can fire twice. Say so, and offer the only real fix.
    @ViewBuilder
    private func conflictNote(for slot: GestureSlot) -> some View {
        if settings.action(for: slot) != .none {
            if let native = slot.nativeConflict, nativeGestures.isActive(native) {
                noteStrip(
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange,
                    text: "macOS also uses this for \(native.systemBehaviour)."
                ) {
                    Button("Turn off") {
                        nativeGestures.setActive(false, for: native)
                        HapticManager.shared.triggerClick()
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .buttonStyle(.borderless)
                }
            } else if let limitation = slot.unavoidableConflict {
                noteStrip(icon: "info.circle.fill", tint: .secondary, text: limitation) { EmptyView() }
            }
        }
    }

    private func noteStrip<Trailing: View>(
        icon: String,
        tint: Color,
        text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.leading, Row.textInset)
        .padding(.trailing, Row.horizontalPadding)
        .padding(.bottom, 7)
    }

    /// Describes what the gesture actually does now, including the reverse
    /// direction of a swipe, instead of a hard-coded caption.
    private func description(for slot: GestureSlot, action: GestureAction) -> String {
        guard action != .none else { return slot.subtitle }

        // Launch App is the one action whose picker label does not say what it
        // will do, so the caption names the target rather than the gesture.
        if action == .launchApp { return "Opens \(launchTargetName)" }

        // Only swipes get a bespoke caption: the direction they run in cannot be
        // read off the picker. For every other slot the picker already names the
        // action, so the caption describes the gesture instead of repeating it.
        let isSwipe = slot.kind == .swipeVertical || slot.kind == .swipeHorizontal
        guard isSwipe else { return slot.subtitle }

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
                // Unbinding a slot is also the moment the macOS gesture it
                // displaced should come back.
                nativeGestures.releaseUnusedDisables()
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
                    .font(.system(size: 9.5, weight: .semibold))
                Text(action.shortTitle)
                    .font(.system(size: 10.5, weight: isAssigned ? .semibold : .regular))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: Row.controlWidth, alignment: .trailing)
            .background(
                // The tint rides on an opaque control colour rather than on the
                // popover's blur: a 12% blue over a light window read as almost
                // nothing, whatever the theme.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isAssigned ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isAssigned ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
            )
            .foregroundColor(isAssigned ? .accentColor : .secondary)
        }
        // `.borderlessButton` discards the label's background and tint;
        // `.button` with a plain button style renders it as designed.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        settingRow(icon: icon, title: title) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.75)
        }
    }

    /// Preference rows share the gesture rows' glyph slot and padding so every
    /// label and divider in the popover sits on the same axis.
    private func settingRow<Trailing: View>(
        icon: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Row.glyphSpacing) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: Row.glyphSize, height: Row.glyphSize)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, Row.horizontalPadding)
        .padding(.vertical, Row.verticalPadding)
    }

    // MARK: - Shared chrome

    private func sectionHeader(icon: String, text: String) -> some View {
        sectionHeader(icon: icon, text: text) { EmptyView() }
    }

    private func sectionHeader<Trailing: View>(
        icon: String,
        text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            trailing()
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.3)
            .padding(.leading, Row.textInset)
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
                        .font(.system(size: 9.5))
                        .foregroundColor(.yellow)
                    Text("GitHub")
                        .font(.system(size: 10.5))
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
                        .font(.system(size: 8.5))
                    Text("Reset Defaults")
                        .font(.system(size: 10.5))
                }
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
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
                        .font(.system(size: 8.5))
                    Text("Quit")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundColor(.red)
                .contentShape(Rectangle())
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
