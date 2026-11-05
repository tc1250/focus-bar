import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let sessionManager = PowerSessionManager()
    private let popover = NSPopover()

    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "FocusBar", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupPopover()

        sessionManager.onStateChange = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }

        if sessionManager.activateOnLaunch {
            sessionManager.startSession(duration: sessionManager.selectedDuration)
        } else {
            updateStatusItem()
        }

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.togglePopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        sessionManager.stopSession()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 350, height: 460)
        updatePopoverAppearance()

        let rootView = FocusPopoverView(
            session: sessionManager,
            onResize: { [weak self] size in
                self?.popover.contentSize = size
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )
        popover.contentViewController = NSHostingController(rootView: rootView)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            if let self,
               self.popover.isShown,
               let clicked = event.window,
               clicked !== self.popover.contentViewController?.view.window,
               clicked !== self.statusItem.button?.window,
               clicked.level.rawValue < NSWindow.Level.popUpMenu.rawValue,
               NSApp.modalWindow == nil {
                self.popover.performClose(nil)
            }
            return event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        let isQuickToggleClick = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
            || event.modifierFlags.contains(.option)

        if isQuickToggleClick {
            sessionManager.toggle()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updatePopoverAppearance()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updatePopoverAppearance() {
        let appearanceName: NSAppearance.Name = sessionManager.palette.isLight ? .aqua : .darkAqua
        popover.appearance = NSAppearance(named: appearanceName)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        updatePopoverAppearance()

        let active = sessionManager.isActive
        button.title = ""
        button.image = MenuBarCapsule.image(
            isActive: active,
            keepDisplayOn: sessionManager.keepDisplayOn,
            progress: sessionManager.progress,
            label: sessionManager.compactRemainingFormatted,
            palette: sessionManager.palette
        )
        button.imagePosition = .imageOnly

        if active {
            let modeText = sessionManager.keepDisplayOn
                ? "Display & System Active"
                : "System Active (Display Can Sleep)"
            if let remaining = sessionManager.remainingTimeFormatted {
                button.toolTip = "FocusBar: \(modeText) (\(remaining))\nLeft-click for panel • Right-click to toggle"
            } else {
                button.toolTip = "FocusBar: \(modeText)\nLeft-click for panel • Right-click to toggle"
            }
        } else {
            button.toolTip = "FocusBar: Inactive (Normal Sleep)\nLeft-click for panel • Right-click to toggle"
        }
    }

    private func quitApp() {
        popover.performClose(nil)
        sessionManager.stopSession()
        NSApp.terminate(nil)
    }
}
