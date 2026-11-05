import AppKit
import Combine
import Foundation
import IOKit
import IOKit.pwr_mgt
import IOKit.ps

enum SessionDuration: Int, CaseIterable, Identifiable {
    case indefinite = 0
    case minutes15 = 900
    case minutes30 = 1800
    case hour1 = 3600
    case hours2 = 7200
    case hours4 = 14400
    case hours8 = 28800

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .indefinite: return "Indefinitely"
        case .minutes15: return "15 Minutes"
        case .minutes30: return "30 Minutes"
        case .hour1: return "1 Hour"
        case .hours2: return "2 Hours"
        case .hours4: return "4 Hours"
        case .hours8: return "8 Hours"
        }
    }

    var shortLabel: String {
        switch self {
        case .indefinite: return "∞"
        case .minutes15: return "15m"
        case .minutes30: return "30m"
        case .hour1: return "1h"
        case .hours2: return "2h"
        case .hours4: return "4h"
        case .hours8: return "8h"
        }
    }
}

struct BatteryInfo {
    let percentage: Int
    let isOnBattery: Bool
}

final class PowerSessionManager: ObservableObject {
    private let isPreview: Bool
    private var displayAssertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var systemAssertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var activityToken: NSObjectProtocol?
    private var countdownTimer: Timer?
    private var appearanceObserver: NSObjectProtocol?

    @Published private(set) var isActive: Bool = false
    @Published private(set) var expirationDate: Date?
    @Published private(set) var selectedDuration: SessionDuration = .indefinite
    @Published private(set) var lastTick: Date = Date()
    @Published private(set) var systemIsDark: Bool = FocusTheme.isSystemDark

    @Published var theme: FocusTheme {
        didSet {
            if !isPreview {
                UserDefaults.standard.set(theme.rawValue, forKey: "colorTheme")
            }
            onStateChange?()
        }
    }

    var palette: FocusPalette {
        theme.resolvedPalette(systemDarkOverride: systemIsDark)
    }

    @Published var keepDisplayOn: Bool {
        didSet {
            if !isPreview {
                UserDefaults.standard.set(keepDisplayOn, forKey: "keepDisplayOn")
            }
            if isActive {
                refreshAssertions()
            } else {
                onStateChange?()
            }
        }
    }

    @Published var autoDisableLowBattery: Bool {
        didSet {
            if !isPreview {
                UserDefaults.standard.set(autoDisableLowBattery, forKey: "autoDisableLowBattery")
            }
            onStateChange?()
        }
    }

    @Published var activateOnLaunch: Bool {
        didSet {
            if !isPreview {
                UserDefaults.standard.set(activateOnLaunch, forKey: "activateOnLaunch")
            }
            onStateChange?()
        }
    }

    var onStateChange: (() -> Void)?

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        let defaults = UserDefaults.standard
        if !isPreview {
            if defaults.object(forKey: "keepDisplayOn") == nil {
                defaults.set(true, forKey: "keepDisplayOn")
            }
            if defaults.object(forKey: "autoDisableLowBattery") == nil {
                defaults.set(true, forKey: "autoDisableLowBattery")
            }
        }
        self.keepDisplayOn = isPreview ? true : defaults.bool(forKey: "keepDisplayOn")
        self.autoDisableLowBattery = isPreview ? true : defaults.bool(forKey: "autoDisableLowBattery")
        self.activateOnLaunch = isPreview ? false : defaults.bool(forKey: "activateOnLaunch")

        let savedThemeRaw = defaults.string(forKey: "colorTheme") ?? FocusTheme.deckDark.rawValue
        self.theme = isPreview ? .deckDark : (FocusTheme(rawValue: savedThemeRaw) ?? .deckDark)

        let savedDurationRaw = defaults.integer(forKey: "defaultDuration")
        self.selectedDuration = isPreview ? .hour1 : (SessionDuration(rawValue: savedDurationRaw) ?? .indefinite)

        if !isPreview {
            appearanceObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.systemIsDark = FocusTheme.isSystemDark
                self.onStateChange?()
            }
        }
    }

    deinit {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
        }
        stopSession()
    }

    func toggle() {
        if isActive {
            stopSession()
        } else {
            startSession(duration: selectedDuration)
        }
    }

    func selectDuration(_ duration: SessionDuration) {
        selectedDuration = duration
        if !isPreview {
            UserDefaults.standard.set(duration.rawValue, forKey: "defaultDuration")
        }
        if isActive {
            startSession(duration: duration)
        } else {
            onStateChange?()
        }
    }

    func startSession(duration: SessionDuration) {
        selectedDuration = duration
        if !isPreview {
            UserDefaults.standard.set(duration.rawValue, forKey: "defaultDuration")
            releaseAssertions()
            acquireAssertions()
        }

        if duration == .indefinite {
            expirationDate = nil
        } else {
            expirationDate = Date().addingTimeInterval(TimeInterval(duration.rawValue))
        }

        isActive = true
        lastTick = Date()
        if !isPreview {
            startTimer()
        }
        onStateChange?()
    }

    func stopSession() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        expirationDate = nil
        releaseAssertions()
        isActive = false
        lastTick = Date()
        onStateChange?()
    }

    /// Fraction between 0.0 and 1.0 representing remaining session progress.
    var progress: Double {
        guard isActive else { return 0.0 }
        guard let exp = expirationDate, selectedDuration.rawValue > 0 else { return 1.0 }
        let remaining = max(0, exp.timeIntervalSinceNow)
        return min(1.0, max(0.0, remaining / Double(selectedDuration.rawValue)))
    }

    var remainingTimeFormatted: String? {
        _ = lastTick
        guard isActive else { return nil }
        guard let exp = expirationDate else { return "Indefinite" }
        let remaining = max(0, Int(exp.timeIntervalSinceNow.rounded()))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%dh %02dm remaining", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds remaining", minutes, seconds)
        } else {
            return String(format: "%ds remaining", seconds)
        }
    }

    var compactRemainingFormatted: String? {
        _ = lastTick
        guard isActive else { return nil }
        guard let exp = expirationDate else { return "ON" }
        let remaining = max(0, Int(exp.timeIntervalSinceNow.rounded()))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    func currentBatteryInfo() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let powerState = info[kIOPSPowerSourceStateKey as String] as? String
            let isOnBattery = (powerState == kIOPSBatteryPowerValue as String)
            if let capacity = info[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey as String] as? Int,
               maxCapacity > 0 {
                let pct = (capacity * 100) / maxCapacity
                return BatteryInfo(percentage: pct, isOnBattery: isOnBattery)
            }
        }
        return nil
    }

    private func refreshAssertions() {
        releaseAssertions()
        acquireAssertions()
        onStateChange?()
    }

    private func acquireAssertions() {
        let reason = "FocusBar active workspace session" as CFString

        if keepDisplayOn {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
        }

        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &systemAssertionID
        )

        var options: ProcessInfo.ActivityOptions = [.idleSystemSleepDisabled, .userInitiated]
        if keepDisplayOn {
            options.insert(.idleDisplaySleepDisabled)
        }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "FocusBar active workspace session"
        )
    }

    private func releaseAssertions() {
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    private func startTimer() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func tick() {
        guard isActive else { return }

        if let exp = expirationDate, Date() >= exp {
            stopSession()
            return
        }

        if autoDisableLowBattery, isBatteryCriticallyLow() {
            stopSession()
            return
        }

        lastTick = Date()
        onStateChange?()
    }

    private func isBatteryCriticallyLow() -> Bool {
        guard let info = currentBatteryInfo() else { return false }
        return info.isOnBattery && info.percentage <= 15
    }
}
