import AppKit

enum MenuBarCapsule {
    static func image(
        isActive: Bool,
        keepDisplayOn: Bool,
        progress: Double,
        label: String?,
        palette: FocusPalette = .deckDark
    ) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        let accentColor: NSColor = isActive
            ? (keepDisplayOn ? palette.activeDisplayNS : palette.activeSystemNS)
            : palette.capsuleIdleRing

        let attrString: NSAttributedString? = {
            guard isActive, let label, !label.isEmpty else { return nil }
            let textColor: NSColor = keepDisplayOn ? palette.capsuleTextPrimary : palette.activeSystemNS
            return NSAttributedString(
                string: label,
                attributes: [.font: font, .foregroundColor: textColor]
            )
        }()

        let height: CGFloat = 24
        let padY: CGFloat = 3
        let ringX: CGFloat = 5
        let ringSize: CGFloat = height - padY * 2

        let textWidth: CGFloat = attrString.map { ceil($0.size().width) } ?? 0
        let width: CGFloat = attrString == nil
            ? (ringX + ringSize + ringX)
            : (ringX + ringSize + 6 + textWidth + 8)

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let capsule = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
            palette.capsuleBackground.setFill()
            capsule.fill()

            let borderColor = isActive ? palette.capsuleBorderActive : palette.capsuleBorderIdle
            borderColor.setStroke()
            capsule.lineWidth = 0.5
            capsule.stroke()

            let ringImg = progressRingImage(
                size: ringSize,
                isActive: isActive,
                color: accentColor,
                progress: progress
            )
            ringImg.draw(in: NSRect(x: ringX, y: padY, width: ringSize, height: ringSize))

            if let attrString {
                let x = ringX + ringSize + 6
                let y = (height - attrString.size().height) / 2
                attrString.draw(at: NSPoint(x: x, y: y))
            }

            return true
        }
        image.isTemplate = false
        return image
    }

    private static func progressRingImage(
        size: CGFloat,
        isActive: Bool,
        color: NSColor,
        progress: Double
    ) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let lineWidth: CGFloat = 2.5
            let radius = min(rect.width, rect.height) / 2 - lineWidth / 2 - 0.5
            let ringRect = NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            let track = NSBezierPath(ovalIn: ringRect)
            track.lineWidth = lineWidth
            color.withAlphaComponent(isActive ? 0.28 : 0.65).setStroke()
            track.stroke()

            if isActive {
                let fraction = min(max(progress, 0.05), 1.0)
                let arc = NSBezierPath()
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - 360 * fraction,
                    clockwise: true
                )
                color.setStroke()
                arc.stroke()

                let dotRadius: CGFloat = 2.2
                let dotRect = NSRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                color.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else {
                let dotRadius: CGFloat = 1.8
                let dotRect = NSRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                color.withAlphaComponent(0.65).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
    }
}
