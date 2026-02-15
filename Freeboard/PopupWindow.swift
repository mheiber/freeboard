import Cocoa

class PopupWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        // Allow key events
        self.becomesKeyOnlyIfNeeded = false

        // Accessibility
        setAccessibilityRole(.popover)
        setAccessibilityLabel(L.accessibilityMainWindow)
        setAccessibilityIdentifier("FreeboardPopupWindow")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
