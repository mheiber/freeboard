import Cocoa

class RetroEffectsView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            return // Skip all CRT effects
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Scanlines
        let scanlineColor = NSColor(white: 0.0, alpha: 0.10)
        context.setFillColor(scanlineColor.cgColor)
        var y: CGFloat = 0
        while y < bounds.height {
            context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 1))
            y += 3
        }

        // CRT edge vignette — stronger corners to simulate convex curvature
        let vignetteGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(white: 0, alpha: 0.5).cgColor,
                NSColor(white: 0, alpha: 0.15).cgColor,
                NSColor(white: 0, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(bounds.width, bounds.height) / 1.4
        context.drawRadialGradient(vignetteGradient,
            startCenter: center, startRadius: radius,
            endCenter: center, endRadius: radius * 0.3,
            options: .drawsAfterEndLocation)

        // CRT glass glare — subtle curved highlight band across upper-center
        // Simulates light reflecting off a convex glass surface
        context.saveGState()
        let glareRect = CGRect(
            x: bounds.width * 0.15,
            y: bounds.height * 0.55,
            width: bounds.width * 0.7,
            height: bounds.height * 0.35
        )
        let glarePath = CGPath(ellipseIn: glareRect, transform: nil)
        context.addPath(glarePath)
        context.clip()

        let glareGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(white: 1.0, alpha: 0.04).cgColor,
                NSColor(white: 1.0, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        let glareCenter = CGPoint(x: bounds.midX, y: bounds.height * 0.72)
        context.drawRadialGradient(glareGradient,
            startCenter: glareCenter, startRadius: 0,
            endCenter: glareCenter, endRadius: bounds.width * 0.4,
            options: .drawsAfterEndLocation)
        context.restoreGState()

        // Secondary glare — faint diagonal streak for realism
        context.saveGState()
        let streakRect = CGRect(
            x: bounds.width * 0.05,
            y: bounds.height * 0.3,
            width: bounds.width * 0.35,
            height: bounds.height * 0.5
        )
        let streakPath = CGPath(ellipseIn: streakRect, transform: nil)
        context.addPath(streakPath)
        context.clip()

        let streakGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(white: 1.0, alpha: 0.025).cgColor,
                NSColor(white: 1.0, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        let streakCenter = CGPoint(x: bounds.width * 0.2, y: bounds.height * 0.55)
        context.drawRadialGradient(streakGradient,
            startCenter: streakCenter, startRadius: 0,
            endCenter: streakCenter, endRadius: bounds.width * 0.2,
            options: .drawsAfterEndLocation)
        context.restoreGState()
    }
}
