import Cocoa

// MARK: - Overlay Window

class ScreenOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.hasShadow = false

        let overlayView = CrackedOverlayView(frame: screen.frame)
        overlayView.autoresizingMask = [.width, .height]
        self.contentView = overlayView
    }
}

// MARK: - Cracked Overlay View

class CrackedOverlayView: NSView {

    private var cracks: [CrackLine] = []

    private struct CrackLine {
        let points: [CGPoint]
        let width: CGFloat
        let alpha: CGFloat
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        generateCracks()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        generateCracks()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - Crack Generation

    private func generateCracks() {
        cracks = []
        var rng = SeededRNG(seed: 42)

        let impacts: [CGPoint] = [
            CGPoint(x: bounds.width * 0.05, y: bounds.height * 0.35),
            CGPoint(x: bounds.width * 0.92, y: bounds.height * 0.85),
            CGPoint(x: bounds.width * 0.15, y: bounds.height * 0.9),
            CGPoint(x: bounds.width * 0.85, y: bounds.height * 0.1),
        ]

        for impact in impacts {
            let numMainCracks = 4 + Int(rng.next() * 4)
            for _ in 0..<numMainCracks {
                let angle = rng.next() * .pi * 2
                let length = 80 + rng.next() * 300
                let mainCrack = generateCrackPath(
                    from: impact, angle: angle, length: length,
                    width: 1.2 + rng.next() * 1.0,
                    alpha: 0.3 + rng.next() * 0.35,
                    rng: &rng
                )
                cracks.append(mainCrack)

                let numBranches = 1 + Int(rng.next() * 3)
                for _ in 0..<numBranches {
                    let branchIdx = 1 + Int(rng.next() * CGFloat(mainCrack.points.count - 2))
                    let branchPoint = mainCrack.points[min(branchIdx, mainCrack.points.count - 1)]
                    let branchAngle = angle + (rng.next() - 0.5) * 1.2
                    let branchLen = 30 + rng.next() * 120
                    let branch = generateCrackPath(
                        from: branchPoint, angle: branchAngle, length: branchLen,
                        width: 0.5 + rng.next() * 0.7,
                        alpha: 0.15 + rng.next() * 0.25,
                        rng: &rng
                    )
                    cracks.append(branch)

                    if rng.next() > 0.5 && branch.points.count > 2 {
                        let microIdx = 1 + Int(rng.next() * CGFloat(branch.points.count - 2))
                        let microPoint = branch.points[min(microIdx, branch.points.count - 1)]
                        let microAngle = branchAngle + (rng.next() - 0.5) * 1.5
                        let microLen = 15 + rng.next() * 50
                        let micro = generateCrackPath(
                            from: microPoint, angle: microAngle, length: microLen,
                            width: 0.3 + rng.next() * 0.4,
                            alpha: 0.1 + rng.next() * 0.15,
                            rng: &rng
                        )
                        cracks.append(micro)
                    }
                }
            }
        }
    }

    private func generateCrackPath(
        from origin: CGPoint, angle: CGFloat, length: CGFloat,
        width: CGFloat, alpha: CGFloat, rng: inout SeededRNG
    ) -> CrackLine {
        var points = [origin]
        var currentAngle = angle
        let segmentLength: CGFloat = 6
        let numSegments = max(1, Int(length / segmentLength))
        var pos = origin

        for _ in 0..<numSegments {
            currentAngle += (rng.next() - 0.5) * 0.4
            let dx = cos(currentAngle) * segmentLength
            let dy = sin(currentAngle) * segmentLength
            pos = CGPoint(x: pos.x + dx, y: pos.y + dy)
            points.append(pos)
        }

        return CrackLine(points: points, width: width, alpha: alpha)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Heavy gray wash — pushes all colors toward grayscale
        // Two layers: dark base to cut brightness, then gray to flatten color
        context.setFillColor(NSColor(white: 0.0, alpha: 0.55).cgColor)
        context.fill(bounds)
        context.setFillColor(NSColor(white: 0.25, alpha: 0.35).cgColor)
        context.fill(bounds)

        // Draw cracks
        for crack in cracks {
            guard crack.points.count >= 2 else { continue }

            // Color fringe
            drawCrackPath(context: context, crack: crack,
                          color: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: crack.alpha * 0.3),
                          offset: CGSize(width: -0.5, height: 0.5),
                          widthScale: 1.5)
            drawCrackPath(context: context, crack: crack,
                          color: NSColor(red: 1.0, green: 0.2, blue: 0.5, alpha: crack.alpha * 0.2),
                          offset: CGSize(width: 0.5, height: -0.5),
                          widthScale: 1.3)

            // Main crack line
            drawCrackPath(context: context, crack: crack,
                          color: NSColor(white: 1.0, alpha: crack.alpha),
                          offset: .zero, widthScale: 1.0)

            // Bright core for thicker cracks
            if crack.width > 1.0 {
                drawCrackPath(context: context, crack: crack,
                              color: NSColor(white: 1.0, alpha: crack.alpha * 0.6),
                              offset: .zero, widthScale: 0.4)
            }
        }

        // Impact point spiderweb circles
        let impactPoints: [CGPoint] = [
            CGPoint(x: bounds.width * 0.05, y: bounds.height * 0.35),
            CGPoint(x: bounds.width * 0.92, y: bounds.height * 0.85),
            CGPoint(x: bounds.width * 0.15, y: bounds.height * 0.9),
            CGPoint(x: bounds.width * 0.85, y: bounds.height * 0.1),
        ]
        for impact in impactPoints {
            context.setStrokeColor(NSColor(white: 1.0, alpha: 0.2).cgColor)
            context.setLineWidth(0.8)
            context.strokeEllipse(in: CGRect(x: impact.x - 8, y: impact.y - 8, width: 16, height: 16))
            context.setStrokeColor(NSColor(white: 1.0, alpha: 0.1).cgColor)
            context.setLineWidth(0.5)
            context.strokeEllipse(in: CGRect(x: impact.x - 18, y: impact.y - 18, width: 36, height: 36))
        }
    }

    private func drawCrackPath(context: CGContext, crack: CrackLine,
                                color: NSColor, offset: CGSize, widthScale: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(crack.width * widthScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.beginPath()
        let first = crack.points[0]
        context.move(to: CGPoint(x: first.x + offset.width, y: first.y + offset.height))
        for i in 1..<crack.points.count {
            let p = crack.points[i]
            context.addLine(to: CGPoint(x: p.x + offset.width, y: p.y + offset.height))
        }
        context.strokePath()
    }
}

// MARK: - Deterministic RNG

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> CGFloat {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return CGFloat(state % 10000) / 10000.0
    }
}
