import Cocoa

class RetroEffectsView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
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
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Scanlines
        let scanlineColor = NSColor(white: 0.0, alpha: 0.10)
        context.setFillColor(scanlineColor.cgColor)
        var y: CGFloat = 0
        while y < bounds.height {
            context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 1))
            y += 3
        }

        // Edge vignette
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(white: 0, alpha: 0.3).cgColor,
                NSColor(white: 0, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(bounds.width, bounds.height) / 1.5
        context.drawRadialGradient(gradient, startCenter: center, startRadius: radius, endCenter: center, endRadius: radius * 0.4, options: .drawsAfterEndLocation)
    }
}
