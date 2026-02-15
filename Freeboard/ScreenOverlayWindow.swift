import Cocoa

// MARK: - Crack Pattern

enum CrackPattern: String, CaseIterable {
    case `default` = "default"
    case x3A7F2B = "0x3A7F2B"
    case xD41E9C = "0xD41E9C"
    case x7B2FA8 = "0x7B2FA8"
    case xE58C14 = "0xE58C14"
    case x1F6DB3 = "0x1F6DB3"
    case x94C0E7 = "0x94C0E7"
    case xF2374A = "0xF2374A"
    case x5E8D61 = "0x5E8D61"
    case xC7190F = "0xC7190F"
    case xA6B8D2 = "0xA6B8D2"

    var displayName: String {
        switch self {
        case .default: return "Default"
        default: return rawValue
        }
    }

    private static let patternKey = "freeboard_crack_pattern"

    static var current: CrackPattern {
        get {
            if let raw = UserDefaults.standard.string(forKey: patternKey),
               let pattern = CrackPattern(rawValue: raw) {
                return pattern
            }
            return .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: patternKey)
        }
    }

    var config: CrackConfig {
        switch self {
        case .default:
            // IMPORTANT: This must remain exactly as the original code —
            // seed 42, same impact points, same parameters.
            return CrackConfig(
                seed: 42,
                impactPoints: [
                    CGPoint(x: 0.05, y: 0.35),
                    CGPoint(x: 0.92, y: 0.85),
                    CGPoint(x: 0.15, y: 0.90),
                    CGPoint(x: 0.85, y: 0.10),
                ],
                mainCracksRange: (4, 4),      // 4 + rng*4 → 4..7
                mainLengthRange: (80, 300),    // 80 + rng*300
                mainWidthRange: (1.2, 1.0),    // 1.2 + rng*1.0
                mainAlphaRange: (0.3, 0.35),   // 0.3 + rng*0.35
                branchCountRange: (1, 3),      // 1 + rng*3
                branchAngleSpread: 1.2,        // +/- 0.6
                branchLengthRange: (30, 120),   // 30 + rng*120
                branchWidthRange: (0.5, 0.7),
                branchAlphaRange: (0.15, 0.25),
                microBranchChance: 0.5,
                microAngleSpread: 1.5,
                microLengthRange: (15, 50),
                microWidthRange: (0.3, 0.4),
                microAlphaRange: (0.1, 0.15),
                segmentLength: 6,
                curvature: 0.4
            )

        case .x3A7F2B:
            // "Corner Shatter" — impacts at the four corners with cracks radiating
            // inward along the edges, visible framing effect without obscuring content
            return CrackConfig(
                seed: 0x3A7F2B,
                impactPoints: [
                    CGPoint(x: 0.02, y: 0.02),
                    CGPoint(x: 0.98, y: 0.02),
                    CGPoint(x: 0.02, y: 0.98),
                    CGPoint(x: 0.98, y: 0.98),
                ],
                mainCracksRange: (4, 3),
                mainLengthRange: (80, 200),
                mainWidthRange: (0.9, 0.7),
                mainAlphaRange: (0.25, 0.25),
                branchCountRange: (1, 3),
                branchAngleSpread: 1.0,
                branchLengthRange: (25, 90),
                branchWidthRange: (0.4, 0.5),
                branchAlphaRange: (0.12, 0.18),
                microBranchChance: 0.5,
                microAngleSpread: 1.2,
                microLengthRange: (10, 35),
                microWidthRange: (0.2, 0.3),
                microAlphaRange: (0.08, 0.12),
                segmentLength: 5,
                curvature: 0.35
            )

        case .xD41E9C:
            // "Lightning Storm" — dramatic jagged cracks with high curvature,
            // thick bold lines, strong contrast
            return CrackConfig(
                seed: 0xD41E9C,
                impactPoints: [
                    CGPoint(x: 0.30, y: 0.70),
                    CGPoint(x: 0.75, y: 0.25),
                ],
                mainCracksRange: (5, 5),
                mainLengthRange: (150, 400),
                mainWidthRange: (1.5, 1.5),
                mainAlphaRange: (0.4, 0.35),
                branchCountRange: (2, 4),
                branchAngleSpread: 1.8,
                branchLengthRange: (40, 180),
                branchWidthRange: (0.8, 1.0),
                branchAlphaRange: (0.2, 0.3),
                microBranchChance: 0.7,
                microAngleSpread: 2.0,
                microLengthRange: (20, 60),
                microWidthRange: (0.4, 0.5),
                microAlphaRange: (0.12, 0.18),
                segmentLength: 5,
                curvature: 0.8
            )

        case .x7B2FA8:
            // "Frost Web" — many impact points with short, fine, densely branching cracks,
            // like ice crystals on a window
            return CrackConfig(
                seed: 0x7B2FA8,
                impactPoints: [
                    CGPoint(x: 0.10, y: 0.20),
                    CGPoint(x: 0.40, y: 0.75),
                    CGPoint(x: 0.70, y: 0.40),
                    CGPoint(x: 0.90, y: 0.80),
                    CGPoint(x: 0.25, y: 0.55),
                    CGPoint(x: 0.80, y: 0.15),
                ],
                mainCracksRange: (3, 3),
                mainLengthRange: (40, 120),
                mainWidthRange: (0.8, 0.6),
                mainAlphaRange: (0.25, 0.25),
                branchCountRange: (2, 4),
                branchAngleSpread: 1.4,
                branchLengthRange: (15, 60),
                branchWidthRange: (0.3, 0.4),
                branchAlphaRange: (0.12, 0.18),
                microBranchChance: 0.8,
                microAngleSpread: 1.6,
                microLengthRange: (8, 30),
                microWidthRange: (0.2, 0.3),
                microAlphaRange: (0.08, 0.12),
                segmentLength: 3,
                curvature: 0.5
            )

        case .xE58C14:
            // "Tectonic" — few massive, bold cracks with very long reach,
            // minimal branching, heavy and dramatic
            return CrackConfig(
                seed: 0xE58C14,
                impactPoints: [
                    CGPoint(x: 0.15, y: 0.50),
                    CGPoint(x: 0.85, y: 0.60),
                ],
                mainCracksRange: (2, 3),
                mainLengthRange: (250, 500),
                mainWidthRange: (2.0, 1.5),
                mainAlphaRange: (0.45, 0.3),
                branchCountRange: (1, 2),
                branchAngleSpread: 0.9,
                branchLengthRange: (60, 200),
                branchWidthRange: (1.0, 0.8),
                branchAlphaRange: (0.2, 0.25),
                microBranchChance: 0.3,
                microAngleSpread: 1.0,
                microLengthRange: (20, 70),
                microWidthRange: (0.5, 0.4),
                microAlphaRange: (0.1, 0.15),
                segmentLength: 8,
                curvature: 0.3
            )

        case .x1F6DB3:
            // "Cascade" — cracks flowing from top to bottom like waterfalls,
            // graceful curves, medium density
            return CrackConfig(
                seed: 0x1F6DB3,
                impactPoints: [
                    CGPoint(x: 0.20, y: 0.95),
                    CGPoint(x: 0.50, y: 0.98),
                    CGPoint(x: 0.80, y: 0.93),
                ],
                mainCracksRange: (4, 4),
                mainLengthRange: (100, 350),
                mainWidthRange: (1.0, 0.8),
                mainAlphaRange: (0.3, 0.3),
                branchCountRange: (1, 3),
                branchAngleSpread: 1.0,
                branchLengthRange: (30, 130),
                branchWidthRange: (0.5, 0.6),
                branchAlphaRange: (0.15, 0.2),
                microBranchChance: 0.5,
                microAngleSpread: 1.2,
                microLengthRange: (12, 45),
                microWidthRange: (0.3, 0.3),
                microAlphaRange: (0.08, 0.12),
                segmentLength: 5,
                curvature: 0.6
            )

        case .x94C0E7:
            // "Whisper" — extremely subtle, very fine hairline cracks,
            // barely visible, elegant and minimal
            return CrackConfig(
                seed: 0x94C0E7,
                impactPoints: [
                    CGPoint(x: 0.08, y: 0.45),
                    CGPoint(x: 0.92, y: 0.55),
                ],
                mainCracksRange: (6, 4),
                mainLengthRange: (60, 250),
                mainWidthRange: (0.4, 0.4),
                mainAlphaRange: (0.15, 0.15),
                branchCountRange: (1, 2),
                branchAngleSpread: 0.7,
                branchLengthRange: (20, 90),
                branchWidthRange: (0.2, 0.3),
                branchAlphaRange: (0.08, 0.12),
                microBranchChance: 0.4,
                microAngleSpread: 0.9,
                microLengthRange: (10, 35),
                microWidthRange: (0.15, 0.2),
                microAlphaRange: (0.05, 0.08),
                segmentLength: 4,
                curvature: 0.2
            )

        case .xF2374A:
            // "Eruption" — single massive impact at corner with explosive spread,
            // dense branching that fans outward
            return CrackConfig(
                seed: 0xF2374A,
                impactPoints: [
                    CGPoint(x: 0.02, y: 0.02),
                ],
                mainCracksRange: (10, 8),
                mainLengthRange: (150, 600),
                mainWidthRange: (1.3, 1.2),
                mainAlphaRange: (0.35, 0.35),
                branchCountRange: (2, 4),
                branchAngleSpread: 1.5,
                branchLengthRange: (40, 160),
                branchWidthRange: (0.6, 0.7),
                branchAlphaRange: (0.15, 0.25),
                microBranchChance: 0.6,
                microAngleSpread: 1.4,
                microLengthRange: (15, 55),
                microWidthRange: (0.3, 0.4),
                microAlphaRange: (0.1, 0.15),
                segmentLength: 6,
                curvature: 0.45
            )

        case .x5E8D61:
            // "Edge Fracture" — impacts along all four edges, cracks run parallel
            // to borders creating a cracked-frame effect around content
            return CrackConfig(
                seed: 0x5E8D61,
                impactPoints: [
                    CGPoint(x: 0.50, y: 0.01),
                    CGPoint(x: 0.50, y: 0.99),
                    CGPoint(x: 0.01, y: 0.50),
                    CGPoint(x: 0.99, y: 0.50),
                    CGPoint(x: 0.15, y: 0.01),
                    CGPoint(x: 0.85, y: 0.99),
                ],
                mainCracksRange: (3, 3),
                mainLengthRange: (100, 250),
                mainWidthRange: (0.8, 0.6),
                mainAlphaRange: (0.25, 0.2),
                branchCountRange: (1, 3),
                branchAngleSpread: 1.1,
                branchLengthRange: (25, 80),
                branchWidthRange: (0.4, 0.4),
                branchAlphaRange: (0.12, 0.15),
                microBranchChance: 0.5,
                microAngleSpread: 1.2,
                microLengthRange: (10, 40),
                microWidthRange: (0.2, 0.3),
                microAlphaRange: (0.08, 0.12),
                segmentLength: 5,
                curvature: 0.4
            )

        case .xC7190F:
            // "Fracture Zone" — diagonal shattering from opposing corners,
            // long reaching cracks that cross the screen
            return CrackConfig(
                seed: 0xC7190F,
                impactPoints: [
                    CGPoint(x: 0.05, y: 0.95),
                    CGPoint(x: 0.95, y: 0.05),
                ],
                mainCracksRange: (6, 5),
                mainLengthRange: (200, 500),
                mainWidthRange: (1.0, 1.0),
                mainAlphaRange: (0.3, 0.35),
                branchCountRange: (2, 3),
                branchAngleSpread: 1.1,
                branchLengthRange: (50, 180),
                branchWidthRange: (0.6, 0.6),
                branchAlphaRange: (0.15, 0.2),
                microBranchChance: 0.55,
                microAngleSpread: 1.3,
                microLengthRange: (15, 50),
                microWidthRange: (0.3, 0.3),
                microAlphaRange: (0.08, 0.12),
                segmentLength: 7,
                curvature: 0.35
            )

        case .xA6B8D2:
            // "Scattered Pebbles" — many small impacts all over the screen,
            // each producing only a few short fine cracks
            return CrackConfig(
                seed: 0xA6B8D2,
                impactPoints: [
                    CGPoint(x: 0.12, y: 0.18),
                    CGPoint(x: 0.45, y: 0.12),
                    CGPoint(x: 0.78, y: 0.22),
                    CGPoint(x: 0.88, y: 0.50),
                    CGPoint(x: 0.72, y: 0.82),
                    CGPoint(x: 0.38, y: 0.88),
                    CGPoint(x: 0.08, y: 0.72),
                    CGPoint(x: 0.55, y: 0.50),
                ],
                mainCracksRange: (2, 2),
                mainLengthRange: (30, 100),
                mainWidthRange: (0.6, 0.5),
                mainAlphaRange: (0.2, 0.2),
                branchCountRange: (1, 2),
                branchAngleSpread: 1.0,
                branchLengthRange: (15, 50),
                branchWidthRange: (0.3, 0.3),
                branchAlphaRange: (0.1, 0.15),
                microBranchChance: 0.4,
                microAngleSpread: 1.0,
                microLengthRange: (8, 25),
                microWidthRange: (0.2, 0.2),
                microAlphaRange: (0.06, 0.1),
                segmentLength: 4,
                curvature: 0.35
            )
        }
    }
}

struct CrackConfig {
    let seed: UInt64
    let impactPoints: [CGPoint]        // Relative coordinates (0..1)
    let mainCracksRange: (Int, Int)     // (base, randomRange) → base + rng * range
    let mainLengthRange: (CGFloat, CGFloat)
    let mainWidthRange: (CGFloat, CGFloat)
    let mainAlphaRange: (CGFloat, CGFloat)
    let branchCountRange: (Int, Int)
    let branchAngleSpread: CGFloat
    let branchLengthRange: (CGFloat, CGFloat)
    let branchWidthRange: (CGFloat, CGFloat)
    let branchAlphaRange: (CGFloat, CGFloat)
    let microBranchChance: CGFloat
    let microAngleSpread: CGFloat
    let microLengthRange: (CGFloat, CGFloat)
    let microWidthRange: (CGFloat, CGFloat)
    let microAlphaRange: (CGFloat, CGFloat)
    let segmentLength: CGFloat
    let curvature: CGFloat
}

// MARK: - Overlay Window

class ScreenOverlayWindow: NSWindow {
    init(screen: NSScreen, pattern: CrackPattern = .current) {
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

        let overlayView = CrackedOverlayView(frame: screen.frame, pattern: pattern)
        overlayView.autoresizingMask = [.width, .height]
        self.contentView = overlayView
        self.setAccessibilityRole(.unknown)
    }
}

// MARK: - Cracked Overlay View

class CrackedOverlayView: NSView {

    private var cracks: [CrackLine] = []
    private let pattern: CrackPattern

    private struct CrackLine {
        let points: [CGPoint]
        let width: CGFloat
        let alpha: CGFloat
    }

    init(frame: NSRect, pattern: CrackPattern = .default) {
        self.pattern = pattern
        super.init(frame: frame)
        generateCracks()
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        self.pattern = .current
        super.init(coder: coder)
        generateCracks()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - Crack Generation

    private func generateCracks() {
        cracks = []
        let config = pattern.config
        var rng = SeededRNG(seed: config.seed)

        let impacts: [CGPoint] = config.impactPoints.map { pt in
            CGPoint(x: bounds.width * pt.x, y: bounds.height * pt.y)
        }

        for impact in impacts {
            let numMainCracks = config.mainCracksRange.0 + Int(rng.next() * CGFloat(config.mainCracksRange.1))
            for _ in 0..<numMainCracks {
                let angle = rng.next() * .pi * 2
                let length = config.mainLengthRange.0 + rng.next() * config.mainLengthRange.1
                let mainCrack = generateCrackPath(
                    from: impact, angle: angle, length: length,
                    width: config.mainWidthRange.0 + rng.next() * config.mainWidthRange.1,
                    alpha: config.mainAlphaRange.0 + rng.next() * config.mainAlphaRange.1,
                    segmentLength: config.segmentLength,
                    curvature: config.curvature,
                    rng: &rng
                )
                cracks.append(mainCrack)

                let numBranches = config.branchCountRange.0 + Int(rng.next() * CGFloat(config.branchCountRange.1))
                for _ in 0..<numBranches {
                    let branchIdx = 1 + Int(rng.next() * CGFloat(mainCrack.points.count - 2))
                    let branchPoint = mainCrack.points[min(branchIdx, mainCrack.points.count - 1)]
                    let branchAngle = angle + (rng.next() - 0.5) * config.branchAngleSpread
                    let branchLen = config.branchLengthRange.0 + rng.next() * config.branchLengthRange.1
                    let branch = generateCrackPath(
                        from: branchPoint, angle: branchAngle, length: branchLen,
                        width: config.branchWidthRange.0 + rng.next() * config.branchWidthRange.1,
                        alpha: config.branchAlphaRange.0 + rng.next() * config.branchAlphaRange.1,
                        segmentLength: config.segmentLength,
                        curvature: config.curvature,
                        rng: &rng
                    )
                    cracks.append(branch)

                    if rng.next() > (1.0 - config.microBranchChance) && branch.points.count > 2 {
                        let microIdx = 1 + Int(rng.next() * CGFloat(branch.points.count - 2))
                        let microPoint = branch.points[min(microIdx, branch.points.count - 1)]
                        let microAngle = branchAngle + (rng.next() - 0.5) * config.microAngleSpread
                        let microLen = config.microLengthRange.0 + rng.next() * config.microLengthRange.1
                        let micro = generateCrackPath(
                            from: microPoint, angle: microAngle, length: microLen,
                            width: config.microWidthRange.0 + rng.next() * config.microWidthRange.1,
                            alpha: config.microAlphaRange.0 + rng.next() * config.microAlphaRange.1,
                            segmentLength: config.segmentLength,
                            curvature: config.curvature,
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
        width: CGFloat, alpha: CGFloat,
        segmentLength: CGFloat, curvature: CGFloat,
        rng: inout SeededRNG
    ) -> CrackLine {
        var points = [origin]
        var currentAngle = angle
        let numSegments = max(1, Int(length / segmentLength))
        var pos = origin

        for _ in 0..<numSegments {
            currentAngle += (rng.next() - 0.5) * curvature
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
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Subtle darkening — enough to set the popup apart without obscuring content
        context.setFillColor(NSColor(white: 0.0, alpha: 0.2).cgColor)
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
        let config = pattern.config
        let impactPoints = config.impactPoints.map { pt in
            CGPoint(x: bounds.width * pt.x, y: bounds.height * pt.y)
        }
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
