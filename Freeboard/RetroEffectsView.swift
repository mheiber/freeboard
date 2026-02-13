import Cocoa

class RetroEffectsView: NSView {
    private var glitchTimer: Timer?
    private var glitchOffset: CGFloat = 0.0
    private var glitchLineY: CGFloat = 0.0
    private var showGlitch = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupTimers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupTimers()
    }

    // Let mouse events pass through to views below
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    private func setupTimers() {
        // Occasional glitch effect
        glitchTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.triggerGlitch()
        }
    }

    private func triggerGlitch() {
        showGlitch = true
        glitchOffset = CGFloat.random(in: -3...3)
        glitchLineY = CGFloat.random(in: 0...bounds.height)
        needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.showGlitch = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Scanlines
        let scanlineColor = NSColor(white: 0.0, alpha: 0.12)
        context.setFillColor(scanlineColor.cgColor)
        var y: CGFloat = 0
        while y < bounds.height {
            context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 1))
            y += 3
        }

        // VCR glitch line
        if showGlitch {
            let glitchRect = CGRect(x: glitchOffset, y: glitchLineY, width: bounds.width, height: 2)
            let glitchColor = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.3)
            context.setFillColor(glitchColor.cgColor)
            context.fill(glitchRect)

            // Displaced horizontal band
            let bandHeight: CGFloat = CGFloat.random(in: 4...12)
            let bandRect = CGRect(x: glitchOffset * 2, y: glitchLineY - bandHeight / 2, width: bounds.width, height: bandHeight)
            let bandColor = NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 0.08)
            context.setFillColor(bandColor.cgColor)
            context.fill(bandRect)
        }

        // Edge vignette
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(white: 0, alpha: 0.4).cgColor,
                NSColor(white: 0, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(bounds.width, bounds.height) / 1.5
        context.drawRadialGradient(gradient, startCenter: center, startRadius: radius, endCenter: center, endRadius: radius * 0.4, options: .drawsAfterEndLocation)
    }

    deinit {
        glitchTimer?.invalidate()
    }
}
