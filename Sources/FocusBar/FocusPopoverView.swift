import AppKit
import SwiftUI
import ServiceManagement

private struct PopoverContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FocusPopoverView: View {
    @ObservedObject var session: PowerSessionManager
    var onResize: (NSSize) -> Void = { _ in }
    var onQuit: () -> Void = {}

    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var loginError: String?

    private static let panelWidth: CGFloat = 350

    private var palette: FocusPalette {
        session.palette
    }

    private var activeColor: Color {
        guard session.isActive else { return palette.secondaryText }
        return session.keepDisplayOn ? palette.activeDisplay : palette.activeSystem
    }

    private var statusBadgeTitle: String {
        if session.isActive {
            return session.keepDisplayOn ? "Display & System" : "System Only"
        }
        return "Idle"
    }

    private var statusBadgeIcon: String {
        if session.isActive {
            return session.keepDisplayOn ? "bolt.circle.fill" : "cpu.fill"
        }
        return "moon.zzz"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(palette.divider)

            VStack(alignment: .leading, spacing: 12) {
                heroSessionCard
                durationSection
                optionsSection
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.card)
                        .cornerRadius(7)
                }
            }
            .padding(12)

            Divider().overlay(palette.divider)
            footerBar
        }
        .frame(width: Self.panelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: PopoverContentHeight.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(PopoverContentHeight.self) { height in
            if height > 0 {
                onResize(NSSize(width: Self.panelWidth, height: ceil(height)))
            }
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .background(palette.background)
        .foregroundColor(palette.primaryText)
        .preferredColorScheme(palette.isLight ? .light : .dark)
        .tint(palette.accent)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: session.isActive ? "bolt.fill" : "bolt")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(session.isActive ? activeColor : palette.accent)
            Text("FocusBar")
                .font(.headline)
                .foregroundColor(palette.primaryText)
            Spacer()
            badge(
                title: statusBadgeTitle,
                icon: statusBadgeIcon,
                color: session.isActive ? activeColor : palette.secondaryText
            )
            themeHeaderMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var themeHeaderMenu: some View {
        Button {
            FocusThemeMenuTarget.popUp(current: session.theme) { selected in
                session.theme = selected
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 12))
                .foregroundColor(palette.secondaryText)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(palette.chipFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Color scheme: \(session.theme.title)")
    }

    // MARK: - Hero Status Card

    private var heroSessionCard: some View {
        panel {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    sessionProgressRing
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.isActive ? "Focus Session Active" : "System Sleep Normal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(palette.primaryText)

                        if session.isActive {
                            Text(session.remainingTimeFormatted ?? "Indefinite session")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(activeColor)
                            Text(session.keepDisplayOn
                                 ? "Display & system sleep prevented"
                                 : "System awake · display can sleep")
                                .font(.system(size: 10))
                                .foregroundColor(palette.secondaryText)
                        } else {
                            Text("Preset: \(session.selectedDuration.title)")
                                .font(.system(size: 11))
                                .foregroundColor(palette.secondaryText)
                            Text("macOS power management is unmodified")
                                .font(.system(size: 10))
                                .foregroundColor(palette.secondaryText.opacity(0.85))
                        }
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    session.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: session.isActive ? "stop.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(session.isActive ? "Stop Focus Session" : "Start Focus Session")
                    }
                }
                .buttonStyle(
                    DeckActionStyle(
                        palette: palette,
                        primary: !session.isActive,
                        danger: session.isActive
                    )
                )
            }
            .padding(12)
        }
    }

    private var sessionProgressRing: some View {
        let progress = session.progress
        let ringColor: Color = session.isActive ? activeColor : palette.secondaryText.opacity(0.45)

        return ZStack {
            Circle()
                .stroke(ringColor.opacity(0.22), lineWidth: 3.5)
            if session.isActive {
                Circle()
                    .trim(from: 0, to: max(0.03, progress))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: session.isActive
                  ? (session.keepDisplayOn ? "display" : "cpu")
                  : "power")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(session.isActive ? ringColor : palette.secondaryText)
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Duration Picker

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            heading(
                "Session duration",
                icon: "clock",
                badgeText: session.selectedDuration.title,
                color: palette.accent
            )
            panel {
                VStack(spacing: 6) {
                    durationChip(for: .indefinite, fullWidth: true)
                    let timed = SessionDuration.allCases.filter { $0 != .indefinite }
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ],
                        spacing: 6
                    ) {
                        ForEach(timed) { duration in
                            durationChip(for: duration, fullWidth: false)
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private func durationChip(for duration: SessionDuration, fullWidth: Bool) -> some View {
        let isSelected = (session.selectedDuration == duration)
        let isRunningThis = session.isActive && isSelected

        return Button {
            session.startSession(duration: duration)
        } label: {
            HStack(spacing: 5) {
                if isRunningThis {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 6, height: 6)
                }
                Text(fullWidth ? "Indefinitely (Until Stopped)" : duration.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(0.16) : palette.chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected ? palette.accent.opacity(0.75) : palette.chipStroke,
                        lineWidth: isSelected ? 1.0 : 0.5
                    )
            )
            .foregroundColor(isSelected ? palette.accent : palette.primaryText.opacity(0.88))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options & Theme Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            heading(
                "Appearance & safeguards",
                icon: "slider.horizontal.3",
                badgeText: nil,
                color: palette.accent
            )
            panel {
                themeChoiceRow
                rowDivider
                preferenceToggle(
                    title: "Keep display on",
                    subtitle: "Prevent screen dimming and lock screen",
                    icon: "display",
                    isOn: Binding(
                        get: { session.keepDisplayOn },
                        set: { session.keepDisplayOn = $0 }
                    )
                )
                rowDivider
                preferenceToggle(
                    title: "Pause on low battery (≤15%)",
                    subtitle: batterySubtitle,
                    icon: "battery.25",
                    isOn: Binding(
                        get: { session.autoDisableLowBattery },
                        set: { session.autoDisableLowBattery = $0 }
                    )
                )
                rowDivider
                preferenceToggle(
                    title: "Activate on launch",
                    subtitle: "Start a session automatically when FocusBar opens",
                    icon: "bolt.badge.clock",
                    isOn: Binding(
                        get: { session.activateOnLaunch },
                        set: { session.activateOnLaunch = $0 }
                    )
                )
                rowDivider
                preferenceToggle(
                    title: "Launch at login",
                    subtitle: "Start FocusBar automatically when you sign in",
                    icon: "person.crop.circle.badge.checkmark",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { _ in toggleLaunchAtLogin() }
                    )
                )
            }
        }
    }

    private var themeChoiceRow: some View {
        HStack(spacing: 9) {
            Image(systemName: "paintpalette")
                .font(.system(size: 12))
                .foregroundColor(palette.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Color scheme")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.primaryText)
                Text(session.theme == .system
                     ? "Follows macOS (\(session.systemIsDark ? "Dark" : "Light"))"
                     : "Saved as your default theme")
                    .font(.system(size: 9.5))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                FocusThemeMenuTarget.popUp(current: session.theme) { selected in
                    session.theme = selected
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 7, height: 7)
                    Text(session.theme.shortTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(palette.accent)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.chipFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(palette.chipStroke, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var batterySubtitle: String {
        guard let info = session.currentBatteryInfo() else {
            return "Auto-stop when running on battery below 15%"
        }
        let source = info.isOnBattery ? "On Battery" : "AC Power"
        return "Currently \(info.percentage)% · \(source)"
    }

    private func toggleLaunchAtLogin() {
        loginError = nil
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } catch {
            loginError = "Login item error: \(error.localizedDescription)"
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Text("v1.0.0 · Right-click icon to quick-toggle")
                .font(.system(size: 10))
                .foregroundColor(palette.secondaryText)
            Spacer()
            Button("Quit") {
                onQuit()
            }
            .buttonStyle(DeckInlineStyle(palette: palette))
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Shared Deck Components

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 1)
            .padding(.horizontal, 10)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .frame(maxWidth: .infinity)
            .background(palette.card)
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(palette.cardBorder, lineWidth: 1)
            )
    }

    private func heading(_ title: String, icon: String, badgeText: String?, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(palette.primaryText)
            if let badgeText {
                Text(badgeText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private func badge(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .cornerRadius(6)
    }

    private func preferenceToggle(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isOn.wrappedValue ? palette.accent : palette.secondaryText)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.primaryText)
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            DeckSwitch(isOn: isOn, palette: palette)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct DeckSwitch: View {
    @Binding var isOn: Bool
    let palette: FocusPalette

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? palette.accent : palette.switchOffFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isOn ? Color.clear : palette.switchOffStroke, lineWidth: 0.5)
                    )
                Circle()
                    .fill(isOn ? (palette.isLight ? .white : palette.background) : palette.switchThumbOff)
                    .frame(width: 12, height: 12)
                    .padding(2)
            }
            .frame(width: 28, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DeckActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    let palette: FocusPalette
    var primary = false
    var danger = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let bg: Color = {
            if primary {
                return enabled ? palette.accent.opacity(pressed ? 0.72 : 0.94) : palette.chipFill
            }
            if danger {
                return Color.orange.opacity(pressed ? 0.25 : 0.16)
            }
            return palette.chipFill.opacity(pressed ? 1.5 : 1.0)
        }()

        let fg: Color = {
            if primary {
                return palette.isLight ? .white : palette.background
            }
            if danger {
                return .orange
            }
            return palette.primaryText
        }()

        return configuration.label
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(danger ? Color.orange.opacity(0.35) : Color.clear, lineWidth: 0.5)
            )
    }
}

private struct DeckInlineStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    let palette: FocusPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(enabled ? palette.primaryText.opacity(0.88) : palette.secondaryText)
            .background(palette.chipFill)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(palette.chipStroke, lineWidth: 0.5)
            )
    }
}

enum FocusPreviewRenderer {
    @MainActor
    static func render(to outputPath: String) -> Bool {
        let deckSession = PowerSessionManager(isPreview: true)
        deckSession.theme = .deckDark
        deckSession.keepDisplayOn = true
        deckSession.startSession(duration: .hour1)

        let lightSession = PowerSessionManager(isPreview: true)
        lightSession.theme = .daylight
        lightSession.keepDisplayOn = true
        lightSession.startSession(duration: .minutes30)

        let midnightSession = PowerSessionManager(isPreview: true)
        midnightSession.theme = .midnight
        midnightSession.stopSession()

        let deckCapsule = MenuBarCapsule.image(
            isActive: true,
            keepDisplayOn: true,
            progress: 0.78,
            label: "47m",
            palette: deckSession.palette
        )
        let lightCapsule = MenuBarCapsule.image(
            isActive: true,
            keepDisplayOn: true,
            progress: 0.65,
            label: "19m",
            palette: lightSession.palette
        )
        let midnightCapsule = MenuBarCapsule.image(
            isActive: false,
            keepDisplayOn: true,
            progress: 0.0,
            label: nil,
            palette: midnightSession.palette
        )

        let showcase = HStack(alignment: .top, spacing: 20) {
            previewColumn(title: "Deck Navy (Dark)", capsule: deckCapsule, session: deckSession)
            previewColumn(title: "Daylight (Light / System)", capsule: lightCapsule, session: lightSession)
            previewColumn(title: "Midnight Violet", capsule: midnightCapsule, session: midnightSession)
        }
        .padding(24)
        .background(Color(red: 0.03, green: 0.05, blue: 0.09))

        let renderer = ImageRenderer(content: showcase)
        renderer.scale = 2.0
        defer {
            deckSession.stopSession()
            lightSession.stopSession()
            midnightSession.stopSession()
        }

        guard let cgImage = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func renderIcon(to outputPath: String) -> Bool {
        let iconView = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.16, blue: 0.25),
                            Color(red: 0.04, green: 0.07, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 824, height: 824)
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color(red: 0.30, green: 0.82, blue: 0.96).opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 6
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 18)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 52)
                .frame(width: 500, height: 500)

            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.30, green: 0.82, blue: 0.96),
                            Color(red: 0.20, green: 0.90, blue: 0.58),
                            Color(red: 0.30, green: 0.82, blue: 0.96)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 52, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 500, height: 500)

            Image(systemName: "bolt.fill")
                .font(.system(size: 230, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.65, green: 0.93, blue: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.30, green: 0.82, blue: 0.96).opacity(0.45), radius: 20, x: 0, y: 6)
        }
        .frame(width: 1024, height: 1024)

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0
        guard let cgImage = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            return true
        } catch {
            return false
        }
    }

    @MainActor
    private static func previewColumn(
        title: String,
        capsule: NSImage,
        session: PowerSessionManager
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Image(nsImage: capsule)
            }
            FocusPopoverView(session: session)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            session.palette.isLight
                                ? Color.black.opacity(0.18)
                                : Color.white.opacity(0.14),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
        }
    }
}
