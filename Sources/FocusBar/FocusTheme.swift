import AppKit
import SwiftUI

enum FocusTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case deckDark = "deck_dark"
    case daylight = "daylight"
    case midnight = "midnight"
    case terminal = "terminal"
    case solarAmber = "solar_amber"
    case nordic = "nordic"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System (Match Mac)"
        case .deckDark: return "Deck Navy (Default)"
        case .daylight: return "Daylight (Light)"
        case .midnight: return "Midnight Violet"
        case .terminal: return "Terminal Phosphor"
        case .solarAmber: return "Solar Amber"
        case .nordic: return "Nordic Frost"
        }
    }

    var shortTitle: String {
        switch self {
        case .system: return "System"
        case .deckDark: return "Deck Navy"
        case .daylight: return "Daylight"
        case .midnight: return "Midnight"
        case .terminal: return "Terminal"
        case .solarAmber: return "Solar Amber"
        case .nordic: return "Nordic"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .deckDark: return "sparkles.rectangle.stack"
        case .daylight: return "sun.max.fill"
        case .midnight: return "moon.stars.fill"
        case .terminal: return "terminal.fill"
        case .solarAmber: return "flame.fill"
        case .nordic: return "snowflake"
        }
    }

    /// Representative swatch color for the theme menu.
    var swatchNSColor: NSColor {
        switch self {
        case .system:
            return Self.isSystemDark ? FocusPalette.deckDark.accentNS : FocusPalette.daylight.accentNS
        default:
            return resolvedPalette().accentNS
        }
    }

    func menuIconImage() -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let img = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            if self == .system {
                // Half-dark, half-light split circle for System theme
                let leftClip = NSRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height)
                NSGraphicsContext.current?.saveGraphicsState()
                NSBezierPath(rect: leftClip).addClip()
                FocusPalette.deckDark.accentNS.setFill()
                NSBezierPath(ovalIn: inset).fill()
                NSGraphicsContext.current?.restoreGraphicsState()

                let rightClip = NSRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height)
                NSGraphicsContext.current?.saveGraphicsState()
                NSBezierPath(rect: rightClip).addClip()
                FocusPalette.daylight.accentNS.setFill()
                NSBezierPath(ovalIn: inset).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            } else {
                let p = self.resolvedPalette()
                p.accentNS.setFill()
                NSBezierPath(ovalIn: inset).fill()
            }
            NSColor.white.withAlphaComponent(0.28).setStroke()
            let border = NSBezierPath(ovalIn: inset)
            border.lineWidth = 0.75
            border.stroke()
            return true
        }
        img.isTemplate = false
        return img
    }

    static var isSystemDark: Bool {
        if let app = NSApp {
            let match = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
        }
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    func resolvedPalette(systemDarkOverride: Bool? = nil) -> FocusPalette {
        switch self {
        case .system:
            let isDark = systemDarkOverride ?? Self.isSystemDark
            return isDark ? .deckDark : .daylight
        case .deckDark:
            return .deckDark
        case .daylight:
            return .daylight
        case .midnight:
            return .midnight
        case .terminal:
            return .terminal
        case .solarAmber:
            return .solarAmber
        case .nordic:
            return .nordic
        }
    }
}

struct FocusPalette {
    let isLight: Bool
    let background: Color
    let card: Color
    let cardBorder: Color
    let divider: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let accentNS: NSColor
    let activeDisplay: Color
    let activeDisplayNS: NSColor
    let activeSystem: Color
    let activeSystemNS: NSColor
    let chipFill: Color
    let chipStroke: Color
    let switchOffFill: Color
    let switchOffStroke: Color
    let switchThumbOff: Color
    let capsuleBackground: NSColor
    let capsuleBorderActive: NSColor
    let capsuleBorderIdle: NSColor
    let capsuleTextPrimary: NSColor
    let capsuleIdleRing: NSColor

    /// Kris's PipelineTracer Deck Navy palette
    static let deckDark = FocusPalette(
        isLight: false,
        background: Color(red: 0.055, green: 0.10, blue: 0.16),
        card: Color(red: 0.10, green: 0.17, blue: 0.25).opacity(0.78),
        cardBorder: Color.white.opacity(0.07),
        divider: Color.white.opacity(0.07),
        primaryText: .white,
        secondaryText: Color.white.opacity(0.60),
        accent: Color(red: 0.30, green: 0.82, blue: 0.96),
        accentNS: NSColor(calibratedRed: 0.30, green: 0.82, blue: 0.96, alpha: 1),
        activeDisplay: .green,
        activeDisplayNS: .systemGreen,
        activeSystem: Color(red: 0.30, green: 0.82, blue: 0.96),
        activeSystemNS: .systemCyan,
        chipFill: Color.white.opacity(0.05),
        chipStroke: Color.white.opacity(0.10),
        switchOffFill: Color.white.opacity(0.14),
        switchOffStroke: Color.white.opacity(0.16),
        switchThumbOff: Color.white.opacity(0.85),
        capsuleBackground: NSColor(calibratedRed: 0.055, green: 0.09, blue: 0.14, alpha: 0.88),
        capsuleBorderActive: NSColor.white.withAlphaComponent(0.24),
        capsuleBorderIdle: NSColor.white.withAlphaComponent(0.15),
        capsuleTextPrimary: .white,
        capsuleIdleRing: .systemGray
    )

    /// Crisp macOS Daylight / Light palette
    static let daylight = FocusPalette(
        isLight: true,
        background: Color(red: 0.95, green: 0.96, blue: 0.98),
        card: Color.white.opacity(0.92),
        cardBorder: Color.black.opacity(0.08),
        divider: Color.black.opacity(0.07),
        primaryText: Color(red: 0.08, green: 0.11, blue: 0.16),
        secondaryText: Color(red: 0.36, green: 0.41, blue: 0.49),
        accent: Color(red: 0.04, green: 0.47, blue: 0.84),
        accentNS: NSColor(calibratedRed: 0.04, green: 0.47, blue: 0.84, alpha: 1),
        activeDisplay: Color(red: 0.10, green: 0.62, blue: 0.32),
        activeDisplayNS: NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.32, alpha: 1),
        activeSystem: Color(red: 0.04, green: 0.47, blue: 0.84),
        activeSystemNS: NSColor(calibratedRed: 0.04, green: 0.47, blue: 0.84, alpha: 1),
        chipFill: Color.black.opacity(0.04),
        chipStroke: Color.black.opacity(0.10),
        switchOffFill: Color.black.opacity(0.12),
        switchOffStroke: Color.black.opacity(0.15),
        switchThumbOff: .white,
        capsuleBackground: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 0.92),
        capsuleBorderActive: NSColor.black.withAlphaComponent(0.22),
        capsuleBorderIdle: NSColor.black.withAlphaComponent(0.14),
        capsuleTextPrimary: NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.16, alpha: 1),
        capsuleIdleRing: NSColor(calibratedWhite: 0.42, alpha: 1)
    )

    /// Deep Obsidian + Electric Violet
    static let midnight = FocusPalette(
        isLight: false,
        background: Color(red: 0.05, green: 0.05, blue: 0.09),
        card: Color(red: 0.10, green: 0.10, blue: 0.17).opacity(0.85),
        cardBorder: Color(red: 0.62, green: 0.50, blue: 1.0).opacity(0.14),
        divider: Color.white.opacity(0.07),
        primaryText: .white,
        secondaryText: Color.white.opacity(0.58),
        accent: Color(red: 0.66, green: 0.55, blue: 0.98),
        accentNS: NSColor(calibratedRed: 0.66, green: 0.55, blue: 0.98, alpha: 1),
        activeDisplay: Color(red: 0.24, green: 0.88, blue: 0.66),
        activeDisplayNS: NSColor(calibratedRed: 0.24, green: 0.88, blue: 0.66, alpha: 1),
        activeSystem: Color(red: 0.66, green: 0.55, blue: 0.98),
        activeSystemNS: NSColor(calibratedRed: 0.66, green: 0.55, blue: 0.98, alpha: 1),
        chipFill: Color.white.opacity(0.05),
        chipStroke: Color.white.opacity(0.10),
        switchOffFill: Color.white.opacity(0.14),
        switchOffStroke: Color.white.opacity(0.16),
        switchThumbOff: Color.white.opacity(0.85),
        capsuleBackground: NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.11, alpha: 0.90),
        capsuleBorderActive: NSColor(calibratedRed: 0.66, green: 0.55, blue: 0.98, alpha: 0.35),
        capsuleBorderIdle: NSColor.white.withAlphaComponent(0.15),
        capsuleTextPrimary: .white,
        capsuleIdleRing: .systemGray
    )

    /// Retro Phosphor Terminal Green
    static let terminal = FocusPalette(
        isLight: false,
        background: Color(red: 0.04, green: 0.09, blue: 0.06),
        card: Color(red: 0.07, green: 0.15, blue: 0.10).opacity(0.82),
        cardBorder: Color(red: 0.20, green: 0.85, blue: 0.48).opacity(0.16),
        divider: Color(red: 0.20, green: 0.85, blue: 0.48).opacity(0.10),
        primaryText: Color(red: 0.90, green: 0.99, blue: 0.93),
        secondaryText: Color(red: 0.55, green: 0.76, blue: 0.62),
        accent: Color(red: 0.22, green: 0.88, blue: 0.50),
        accentNS: NSColor(calibratedRed: 0.22, green: 0.88, blue: 0.50, alpha: 1),
        activeDisplay: Color(red: 0.22, green: 0.88, blue: 0.50),
        activeDisplayNS: NSColor(calibratedRed: 0.22, green: 0.88, blue: 0.50, alpha: 1),
        activeSystem: Color(red: 0.45, green: 0.95, blue: 0.75),
        activeSystemNS: NSColor(calibratedRed: 0.45, green: 0.95, blue: 0.75, alpha: 1),
        chipFill: Color.white.opacity(0.04),
        chipStroke: Color(red: 0.22, green: 0.88, blue: 0.50).opacity(0.18),
        switchOffFill: Color.white.opacity(0.12),
        switchOffStroke: Color.white.opacity(0.15),
        switchThumbOff: Color.white.opacity(0.85),
        capsuleBackground: NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.06, alpha: 0.90),
        capsuleBorderActive: NSColor(calibratedRed: 0.22, green: 0.88, blue: 0.50, alpha: 0.35),
        capsuleBorderIdle: NSColor.white.withAlphaComponent(0.15),
        capsuleTextPrimary: NSColor(calibratedRed: 0.90, green: 0.99, blue: 0.93, alpha: 1),
        capsuleIdleRing: .systemGray
    )

    /// Warm Espresso + Solar Amber
    static let solarAmber = FocusPalette(
        isLight: false,
        background: Color(red: 0.10, green: 0.08, blue: 0.06),
        card: Color(red: 0.16, green: 0.13, blue: 0.10).opacity(0.85),
        cardBorder: Color(red: 0.98, green: 0.68, blue: 0.25).opacity(0.14),
        divider: Color.white.opacity(0.07),
        primaryText: Color(red: 0.99, green: 0.96, blue: 0.92),
        secondaryText: Color(red: 0.75, green: 0.67, blue: 0.58),
        accent: Color(red: 0.98, green: 0.68, blue: 0.22),
        accentNS: NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.22, alpha: 1),
        activeDisplay: Color(red: 0.98, green: 0.68, blue: 0.22),
        activeDisplayNS: NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.22, alpha: 1),
        activeSystem: Color(red: 0.95, green: 0.50, blue: 0.20),
        activeSystemNS: NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.20, alpha: 1),
        chipFill: Color.white.opacity(0.05),
        chipStroke: Color.white.opacity(0.10),
        switchOffFill: Color.white.opacity(0.14),
        switchOffStroke: Color.white.opacity(0.16),
        switchThumbOff: Color.white.opacity(0.85),
        capsuleBackground: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.06, alpha: 0.90),
        capsuleBorderActive: NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.22, alpha: 0.35),
        capsuleBorderIdle: NSColor.white.withAlphaComponent(0.15),
        capsuleTextPrimary: .white,
        capsuleIdleRing: .systemGray
    )

    /// Nord Polar Slate + Frost Cyan
    static let nordic = FocusPalette(
        isLight: false,
        background: Color(red: 0.18, green: 0.20, blue: 0.25),
        card: Color(red: 0.23, green: 0.26, blue: 0.32).opacity(0.88),
        cardBorder: Color.white.opacity(0.09),
        divider: Color.white.opacity(0.08),
        primaryText: Color(red: 0.93, green: 0.94, blue: 0.96),
        secondaryText: Color(red: 0.70, green: 0.74, blue: 0.81),
        accent: Color(red: 0.53, green: 0.75, blue: 0.82),
        accentNS: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 1),
        activeDisplay: Color(red: 0.64, green: 0.75, blue: 0.55),
        activeDisplayNS: NSColor(calibratedRed: 0.64, green: 0.75, blue: 0.55, alpha: 1),
        activeSystem: Color(red: 0.53, green: 0.75, blue: 0.82),
        activeSystemNS: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 1),
        chipFill: Color.white.opacity(0.06),
        chipStroke: Color.white.opacity(0.12),
        switchOffFill: Color.white.opacity(0.16),
        switchOffStroke: Color.white.opacity(0.18),
        switchThumbOff: Color.white.opacity(0.88),
        capsuleBackground: NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.25, alpha: 0.90),
        capsuleBorderActive: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 0.35),
        capsuleBorderIdle: NSColor.white.withAlphaComponent(0.16),
        capsuleTextPrimary: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1),
        capsuleIdleRing: NSColor(calibratedRed: 0.60, green: 0.65, blue: 0.73, alpha: 1)
    )
}

final class FocusThemeMenuTarget: NSObject {
    static let shared = FocusThemeMenuTarget()
    var onSelect: ((FocusTheme) -> Void)?

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = FocusTheme(rawValue: raw) else { return }
        onSelect?(theme)
    }

    static func popUp(current: FocusTheme, onSelect: @escaping (FocusTheme) -> Void) {
        shared.onSelect = onSelect
        let menu = NSMenu(title: "Color Scheme")
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Color Scheme", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(makeItem(for: .system, current: current))
        menu.addItem(.separator())

        for theme in FocusTheme.allCases where theme != .system {
            menu.addItem(makeItem(for: theme, current: current))
        }

        if let event = NSApp.currentEvent, let view = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    private static func makeItem(for theme: FocusTheme, current: FocusTheme) -> NSMenuItem {
        let item = NSMenuItem(
            title: theme.title,
            action: #selector(selectTheme(_:)),
            keyEquivalent: ""
        )
        item.target = shared
        item.representedObject = theme.rawValue
        item.state = (theme == current) ? .on : .off
        item.image = theme.menuIconImage()
        return item
    }
}
