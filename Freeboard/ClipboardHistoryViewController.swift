import Cocoa
import WebKit

protocol ClipboardHistoryDelegate: AnyObject {
    func didSelectEntry(_ entry: ClipboardEntry)
    func didSelectEntryAsPlainText(_ entry: ClipboardEntry)
    func didSelectEntryAsRenderedMarkdown(_ entry: ClipboardEntry)
    func didSelectEntryAsSyntaxHighlightedCode(_ entry: ClipboardEntry, language: String)
    func didDeleteEntry(_ entry: ClipboardEntry)
    func didDismiss()
}

/// An NSButton subclass that shows an underline on its attributed title
/// when the mouse hovers over it, giving a visual "clickable" affordance.
private class HoverUnderlineButton: NSButton {
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        let current = attributedTitle
        let mutable = NSMutableAttributedString(attributedString: current)
        mutable.addAttribute(.underlineStyle,
                             value: NSUnderlineStyle.single.rawValue,
                             range: NSRange(location: 0, length: mutable.length))
        attributedTitle = mutable
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        let current = attributedTitle
        let mutable = NSMutableAttributedString(attributedString: current)
        mutable.removeAttribute(.underlineStyle,
                                range: NSRange(location: 0, length: mutable.length))
        attributedTitle = mutable
    }
}

class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate, NSGestureRecognizerDelegate, MonacoEditorDelegate, NSMenuDelegate {

    weak var historyDelegate: ClipboardHistoryDelegate?
    var clipboardManager: ClipboardManager?

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var searchField: NSTextField!
    private var helpLabel: NSStackView!
    private var containerView: NSView!
    private var effectsView: RetroEffectsView!
    private var emptyStateView: NSView!
    private var clearSearchButton: NSButton!
    private var accessibilityHintButton: NSButton!
    private var permissionWarningButton: NSButton!
    private var helpButton: NSButton!
    private var escCloseButton: NSButton!
    private var helpOverlay: NSView?
    private var helpFocusableItems: [NSButton] = []
    private var helpFocusIndex: Int = -1
    private var helpHasBackButton: Bool = false
    private var settingsArrowWindow: NSWindow?
    private var permissionTooltipView: NSView?

    private var filteredEntries: [ClipboardEntry] = []
    private var selectedIndex: Int = 0
    private var expandedIndex: Int? = nil
    private var editingIndex: Int? = nil
    private var editTextView: NSTextView? = nil
    private var monacoEditorView: MonacoEditorView? = nil
    private var preloadedMonacoEditor: MonacoEditorView? = nil
    private var monacoEditingIndex: Int? = nil
    private var searchQuery: String = ""
    private var hoveredRow: Int? = nil
    private var mouseInIndicatorZone: Bool = false
    private var keyMonitor: Any?

    private let retroGreen = NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)
    private let retroDimGreen = NSColor(red: 0.0, green: 0.75, blue: 0.19, alpha: 1.0)
    private let retroBg = NSColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 0.88)
    private let retroSelectionBg = NSColor(red: 0.0, green: 0.2, blue: 0.05, alpha: 0.9)

    private var effectiveRetroGreen: NSColor {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)
        }
        return retroGreen
    }

    private var effectiveDimGreen: NSColor {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)
        }
        return retroDimGreen
    }

    private var effectiveBg: NSColor {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            return NSColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0)
        }
        return retroBg
    }
    private var retroFont: NSFont {
        if L.current.usesSystemFont {
            return NSFont.systemFont(ofSize: 20, weight: .regular)
        }
        return NSFont(name: "Menlo", size: 16) ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    private var retroFontStar: NSFont {
        if L.current.usesSystemFont {
            return NSFont.systemFont(ofSize: 26, weight: .regular)
        }
        return NSFont(name: "Menlo", size: 22) ?? NSFont.monospacedSystemFont(ofSize: 22, weight: .regular)
    }
    private var retroFontSmall: NSFont {
        if L.current.usesSystemFont {
            return NSFont.systemFont(ofSize: 15, weight: .regular)
        }
        return NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    override func loadView() {
        let frame = NSRect(x: 0, y: 0, width: 900, height: 750)
        let mainView = NSView(frame: frame)
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = effectiveBg.cgColor
        mainView.layer?.cornerRadius = 8
        mainView.layer?.borderColor = retroGreen.withAlphaComponent(0.3).cgColor
        mainView.layer?.borderWidth = 1

        // Phosphor glow — soft green haze radiating from the border
        mainView.layer?.shadowColor = retroGreen.withAlphaComponent(0.6).cgColor
        mainView.layer?.shadowRadius = 15
        mainView.layer?.shadowOpacity = 1.0
        mainView.layer?.shadowOffset = .zero
        mainView.layer?.masksToBounds = false

        containerView = mainView
        containerView.setAccessibilityIdentifier("FreeboardContainer")
        setupSearchField()
        setupTableView()
        setupHelpLabel()
        setupEmptyState()

        effectsView = RetroEffectsView(frame: frame)
        effectsView.autoresizingMask = [.width, .height]
        mainView.addSubview(effectsView)

        self.view = mainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadEntries()
        preloadMonacoEditor()
    }

    private func preloadMonacoEditor() {
        let editor = MonacoEditorView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        editor.isHidden = true
        view.addSubview(editor)
        editor.loadEditor()
        preloadedMonacoEditor = editor
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()
        searchField.stringValue = ""
        searchQuery = ""
        selectedIndex = 0
        refreshLocalization()
        reloadEntries()
        updateAccessibilityHint()
        updatePermissionWarning()
        view.window?.makeFirstResponder(self)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command, event.charactersIgnoringModifiers == "s", self.editingIndex == nil {
                self.toggleStarOnSelected()
                return nil
            }
            if flags == .command, event.charactersIgnoringModifiers == "d", self.editingIndex == nil {
                self.deleteSelected()
                return nil
            }
            return event
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        dismissHelp()
        dismissPermissionTooltip()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func refreshLocalization() {
        searchField.font = retroFont
        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.5),
            .font: retroFont
        ]
        searchField.placeholderAttributedString = NSAttributedString(
            string: L.searchPlaceholder, attributes: placeholderAttrs
        )
        populateHelpBar()
        helpButton.attributedTitle = makeHelpButtonTitle()
        helpButton.setAccessibilityLabel(L.help)
        escCloseButton.attributedTitle = makeEscCloseButtonTitle()
        escCloseButton.setAccessibilityLabel("Esc \(L.close)")
        let warningAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.orange,
            .font: retroFontSmall
        ]
        permissionWarningButton.attributedTitle = NSAttributedString(
            string: "⚠ \(L.permissionWarningButtonTitle)",
            attributes: warningAttrs
        )
        permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
        updateEmptyStateStrings()
        tableView?.reloadData()
    }

    // MARK: - Setup

    private func setupSearchField() {
        searchField = NSTextField(frame: .zero)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = retroFont
        searchField.textColor = retroGreen
        searchField.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.85)
        searchField.drawsBackground = true
        searchField.isBezeled = true
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .default
        searchField.delegate = self
        searchField.setAccessibilityLabel(L.accessibilitySearchField)

        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.5),
            .font: retroFont
        ]
        searchField.placeholderAttributedString = NSAttributedString(
            string: L.searchPlaceholder, attributes: placeholderAttrs
        )

        searchField.setAccessibilityIdentifier("SearchField")

        containerView.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func setupTableView() {
        tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.rowHeight = 50
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(tableClicked)
        tableView.setAccessibilityIdentifier("ClipboardHistoryTable")

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        column.width = 876
        tableView.addTableColumn(column)

        scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        containerView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 54),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])

        // Tracking area for hover detection on the table view
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        tableView.addTrackingArea(trackingArea)

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        tableView.menu = contextMenu
    }

    private func setupHelpLabel() {
        helpLabel = NSStackView()
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.orientation = .horizontal
        helpLabel.spacing = 0
        helpLabel.alignment = .centerY
        populateHelpBar()

        helpButton = NSButton(title: "", target: self, action: #selector(helpButtonClicked))
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.isBordered = false
        helpButton.attributedTitle = makeHelpButtonTitle()
        helpButton.setAccessibilityLabel(L.help)

        escCloseButton = NSButton(title: "", target: self, action: #selector(escCloseClicked))
        escCloseButton.translatesAutoresizingMaskIntoConstraints = false
        escCloseButton.isBordered = false
        escCloseButton.attributedTitle = makeEscCloseButtonTitle()
        escCloseButton.setAccessibilityLabel("Esc \(L.close)")

        permissionWarningButton = NSButton(title: "", target: self, action: #selector(permissionWarningClicked))
        permissionWarningButton.translatesAutoresizingMaskIntoConstraints = false
        permissionWarningButton.isBordered = false
        let warningAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.orange,
            .font: retroFontSmall
        ]
        permissionWarningButton.attributedTitle = NSAttributedString(
            string: "\u{26A0} \(L.permissionWarningButtonTitle)",
            attributes: warningAttrs
        )
        permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
        permissionWarningButton.isHidden = true

        let warningTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["zone": "permissionWarning"]
        )
        permissionWarningButton.addTrackingArea(warningTrackingArea)

        containerView.addSubview(helpLabel)
        containerView.addSubview(permissionWarningButton)
        containerView.addSubview(helpButton)
        containerView.addSubview(escCloseButton)

        NSLayoutConstraint.activate([
            helpLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -7),
            helpLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            helpLabel.trailingAnchor.constraint(lessThanOrEqualTo: permissionWarningButton.leadingAnchor, constant: -6),
            helpLabel.heightAnchor.constraint(equalToConstant: 18),

            permissionWarningButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            permissionWarningButton.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -6),
            permissionWarningButton.heightAnchor.constraint(equalToConstant: 20),

            helpButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            helpButton.trailingAnchor.constraint(equalTo: escCloseButton.leadingAnchor, constant: -4),
            helpButton.heightAnchor.constraint(equalToConstant: 20),

            escCloseButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            escCloseButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            escCloseButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @objc private func helpButtonClicked() {
        toggleHelp()
    }

    @objc private func escCloseClicked() {
        historyDelegate?.didDismiss()
    }

    func toggleHelp() {
        if let overlay = helpOverlay, overlay.superview != nil {
            dismissHelp()
        } else {
            showHelp()
        }
    }

    private func showHelp() {
        let overlay = NSView(frame: containerView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.95).cgColor

        // Close help button at top left (like back buttons on sub-screens)
        let bodyFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .regular)
            : NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let closeHelpButton = NSButton(title: "", target: self, action: #selector(closeHelpClicked))
        closeHelpButton.translatesAutoresizingMaskIntoConstraints = false
        closeHelpButton.isBordered = false
        let closeHelpAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        closeHelpButton.attributedTitle = NSAttributedString(string: L.helpCloseHelp, attributes: closeHelpAttrs)
        closeHelpButton.setAccessibilityLabel(L.helpCloseHelp)
        overlay.addSubview(closeHelpButton)

        let helpContent = NSTextField(labelWithString: "")
        helpContent.translatesAutoresizingMaskIntoConstraints = false
        helpContent.backgroundColor = .clear
        helpContent.isBezeled = false
        helpContent.isEditable = false
        helpContent.maximumNumberOfLines = 0
        helpContent.lineBreakMode = .byWordWrapping
        helpContent.alignment = .center
        helpContent.attributedStringValue = makeHelpContent()

        // Power Features section
        let sectionFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

        let sectionLabel = NSTextField(labelWithString: L.helpPowerFeatures)
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionLabel.backgroundColor = .clear
        sectionLabel.isBezeled = false
        sectionLabel.isEditable = false
        sectionLabel.font = sectionFont
        sectionLabel.textColor = retroDimGreen.withAlphaComponent(0.5)
        sectionLabel.alignment = .center

        let markdownLinkButton = NSButton(title: "", target: self, action: #selector(markdownLinkClicked))
        markdownLinkButton.translatesAutoresizingMaskIntoConstraints = false
        markdownLinkButton.isBordered = false
        let linkFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 16, weight: .regular)
            : NSFont(name: "Menlo", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: linkFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        markdownLinkButton.attributedTitle = NSAttributedString(string: L.helpMarkdownLink, attributes: linkAttrs)
        markdownLinkButton.setAccessibilityLabel(L.markdownSupport)

        let editingLinkButton = NSButton(title: "", target: self, action: #selector(editingLinkClicked))
        editingLinkButton.translatesAutoresizingMaskIntoConstraints = false
        editingLinkButton.isBordered = false
        editingLinkButton.attributedTitle = NSAttributedString(string: L.helpEditingLink, attributes: linkAttrs)
        editingLinkButton.setAccessibilityLabel(L.editing)

        let settingsLinkButton = NSButton(title: "", target: self, action: #selector(settingsLinkClicked))
        settingsLinkButton.translatesAutoresizingMaskIntoConstraints = false
        settingsLinkButton.isBordered = false
        settingsLinkButton.attributedTitle = NSAttributedString(string: L.helpSettingsLink, attributes: linkAttrs)
        settingsLinkButton.setAccessibilityLabel(L.settings)

        let dismissLabel = NSTextField(labelWithString: "")
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        dismissLabel.backgroundColor = .clear
        dismissLabel.isBezeled = false
        dismissLabel.isEditable = false
        dismissLabel.alignment = .center
        dismissLabel.attributedStringValue = makeDismissString()

        overlay.addSubview(helpContent)
        overlay.addSubview(sectionLabel)
        overlay.addSubview(markdownLinkButton)
        overlay.addSubview(editingLinkButton)
        overlay.addSubview(settingsLinkButton)
        overlay.addSubview(dismissLabel)

        // Track focusable items for keyboard navigation
        helpFocusableItems = [closeHelpButton, markdownLinkButton, editingLinkButton, settingsLinkButton]
        helpFocusIndex = -1
        helpHasBackButton = true

        if !AXIsProcessTrusted() {
            let accessibilityButton = NSButton(title: "", target: self, action: #selector(helpAccessibilityClicked))
            accessibilityButton.translatesAutoresizingMaskIntoConstraints = false
            accessibilityButton.isBordered = false
            let dimFont = L.current.usesSystemFont
                ? NSFont.systemFont(ofSize: 14, weight: .regular)
                : NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
                .font: dimFont
            ]
            let accLinkAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: retroGreen.withAlphaComponent(0.8),
                .font: dimFont,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            let attrStr = NSMutableAttributedString()
            attrStr.append(NSAttributedString(string: L.helpAccessibility + " ", attributes: hintAttrs))
            attrStr.append(NSAttributedString(string: L.helpAccessibilityLink, attributes: accLinkAttrs))
            attrStr.append(NSAttributedString(string: ",\n" + L.helpAccessibilitySteps, attributes: hintAttrs))
            accessibilityButton.attributedTitle = attrStr
            overlay.addSubview(accessibilityButton)

            // Include accessibility button before the link buttons
            helpFocusableItems = [closeHelpButton, accessibilityButton, markdownLinkButton, editingLinkButton, settingsLinkButton]

            NSLayoutConstraint.activate([
                accessibilityButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                accessibilityButton.topAnchor.constraint(equalTo: helpContent.bottomAnchor, constant: 24),
                accessibilityButton.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 60),
                accessibilityButton.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -60),
            ])

            NSLayoutConstraint.activate([
                sectionLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                sectionLabel.topAnchor.constraint(equalTo: accessibilityButton.bottomAnchor, constant: 24),

                markdownLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                markdownLinkButton.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),

                editingLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                editingLinkButton.topAnchor.constraint(equalTo: markdownLinkButton.bottomAnchor, constant: 4),

                settingsLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                settingsLinkButton.topAnchor.constraint(equalTo: editingLinkButton.bottomAnchor, constant: 4),
            ])
        } else {
            NSLayoutConstraint.activate([
                sectionLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                sectionLabel.topAnchor.constraint(equalTo: helpContent.bottomAnchor, constant: 32),

                markdownLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                markdownLinkButton.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),

                editingLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                editingLinkButton.topAnchor.constraint(equalTo: markdownLinkButton.bottomAnchor, constant: 4),

                settingsLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                settingsLinkButton.topAnchor.constraint(equalTo: editingLinkButton.bottomAnchor, constant: 4),
            ])
        }

        // Insert below effectsView so CRT effects still show on top
        let effectsIndex = containerView.subviews.firstIndex(of: effectsView) ?? containerView.subviews.count
        containerView.addSubview(overlay, positioned: .below, relativeTo: effectsView)
        _ = effectsIndex // suppress warning

        NSLayoutConstraint.activate([
            closeHelpButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 16),
            closeHelpButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),

            helpContent.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            helpContent.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -60),
            helpContent.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 60),
            helpContent.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -60),

            dismissLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dismissLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24),
        ])

        helpOverlay = overlay
    }

    private func dismissHelp() {
        helpOverlay?.removeFromSuperview()
        helpOverlay = nil
        helpFocusableItems = []
        helpFocusIndex = -1
        helpHasBackButton = false
        settingsArrowWindow?.orderOut(nil)
        settingsArrowWindow = nil
    }

    private func helpMoveFocus(by delta: Int) {
        guard !helpFocusableItems.isEmpty else { return }
        // Remove highlight from current
        if helpFocusIndex >= 0 && helpFocusIndex < helpFocusableItems.count {
            updateHelpButtonHighlight(helpFocusableItems[helpFocusIndex], highlighted: false)
        }
        // Move focus
        if helpFocusIndex < 0 {
            helpFocusIndex = delta > 0 ? 0 : helpFocusableItems.count - 1
        } else {
            helpFocusIndex = helpFocusIndex + delta
            if helpFocusIndex < 0 { helpFocusIndex = helpFocusableItems.count - 1 }
            if helpFocusIndex >= helpFocusableItems.count { helpFocusIndex = 0 }
        }
        // Apply highlight to new
        updateHelpButtonHighlight(helpFocusableItems[helpFocusIndex], highlighted: true)
        // Update VoiceOver focus
        NSAccessibility.post(element: helpFocusableItems[helpFocusIndex], notification: .focusedUIElementChanged)
    }

    private func helpActivateFocused() {
        guard helpFocusIndex >= 0, helpFocusIndex < helpFocusableItems.count else { return }
        helpFocusableItems[helpFocusIndex].performClick(nil)
    }

    private func helpGoBack() {
        guard helpHasBackButton, !helpFocusableItems.isEmpty else { return }
        // The back button is always the first focusable item on sub-screens
        helpFocusableItems[0].performClick(nil)
    }

    private func updateHelpButtonHighlight(_ button: NSButton, highlighted: Bool) {
        guard let attrTitle = button.attributedTitle.mutableCopy() as? NSMutableAttributedString else { return }
        let range = NSRange(location: 0, length: attrTitle.length)
        if highlighted {
            // Inverse: green background, dark text
            attrTitle.addAttribute(.backgroundColor, value: retroGreen.withAlphaComponent(0.85), range: range)
            attrTitle.addAttribute(.foregroundColor, value: NSColor.black, range: range)
        } else {
            attrTitle.removeAttribute(.backgroundColor, range: range)
            attrTitle.addAttribute(.foregroundColor, value: retroGreen.withAlphaComponent(0.8), range: range)
        }
        button.attributedTitle = attrTitle
    }

    @objc private func helpOverlayClicked() {
        dismissHelp()
    }

    @objc private func closeHelpClicked() {
        dismissHelp()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        guard let overlay = helpOverlay else { return true }
        let location = gestureRecognizer.location(in: overlay)
        let hitView = overlay.hitTest(location)
        // Don't dismiss if the click landed on a button
        return !(hitView is NSButton || hitView?.superview is NSButton)
    }

    @objc private func helpAccessibilityClicked() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    @objc private func markdownLinkClicked() {
        dismissHelp()
        showMarkdownHelp()
    }

    @objc private func markdownBackClicked() {
        dismissHelp()
        showHelp()
    }

    @objc private func editingLinkClicked() {
        dismissHelp()
        showEditingHelp()
    }

    @objc private func editingBackClicked() {
        dismissHelp()
        showHelp()
    }

    @objc private func editingSeeMarkdownClicked() {
        dismissHelp()
        showMarkdownHelp()
    }

    @objc private func editingVimToggleClicked() {
        let current = UserDefaults.standard.bool(forKey: "vimModeEnabled")
        UserDefaults.standard.set(!current, forKey: "vimModeEnabled")
        dismissHelp()
        showEditingHelp()
    }

    @objc private func settingsLinkClicked() {
        dismissHelp()
        showSettingsHelp()
    }

    @objc private func settingsBackClicked() {
        dismissHelp()
        showHelp()
    }

    private func showSettingsHelp() {
        let overlay = NSView(frame: containerView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.95).cgColor

        let titleFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 22, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let bodyFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .regular)
            : NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let arrowFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 28, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 24) ?? NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)

        // Back button
        let backButton = NSButton(title: "", target: self, action: #selector(settingsBackClicked))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        let backAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        backButton.attributedTitle = NSAttributedString(string: L.markdownHelpBack, attributes: backAttrs)
        backButton.setAccessibilityLabel(L.help)
        overlay.addSubview(backButton)

        // Content
        let leftPara = NSMutableParagraphStyle()
        leftPara.alignment = .left
        leftPara.lineSpacing = 4

        let centerPara = NSMutableParagraphStyle()
        centerPara.alignment = .center
        centerPara.lineSpacing = 6

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: titleFont,
            .paragraphStyle: leftPara
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen,
            .font: bodyFont,
            .paragraphStyle: leftPara
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: bodyFont,
            .paragraphStyle: leftPara
        ]

        let str = NSMutableAttributedString()
        str.append(NSAttributedString(string: L.settings.uppercased(), attributes: titleAttrs))
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.settingsHelpRightClick, attributes: bodyAttrs))
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.settingsHelpAvailable, attributes: dimAttrs))

        let helpContent = NSTextField(labelWithString: "")
        helpContent.translatesAutoresizingMaskIntoConstraints = false
        helpContent.backgroundColor = .clear
        helpContent.isBezeled = false
        helpContent.isEditable = false
        helpContent.maximumNumberOfLines = 0
        helpContent.lineBreakMode = .byWordWrapping
        helpContent.alignment = .left
        helpContent.attributedStringValue = str

        // Arrow pointing up toward the menu bar
        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: arrowFont,
            .paragraphStyle: centerPara
        ]
        let arrowLabel = NSTextField(labelWithString: "")
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowLabel.backgroundColor = .clear
        arrowLabel.isBezeled = false
        arrowLabel.isEditable = false
        arrowLabel.attributedStringValue = NSAttributedString(string: "[F]", attributes: arrowAttrs)

        let dismissLabel = NSTextField(labelWithString: "")
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        dismissLabel.backgroundColor = .clear
        dismissLabel.isBezeled = false
        dismissLabel.isEditable = false
        dismissLabel.alignment = .center
        dismissLabel.attributedStringValue = makeDismissString(withBackNav: true)

        overlay.addSubview(helpContent)
        overlay.addSubview(arrowLabel)
        overlay.addSubview(dismissLabel)

        // Track focusable items for keyboard navigation
        helpFocusableItems = [backButton]
        helpFocusIndex = -1
        helpHasBackButton = true

        // Insert below effectsView so CRT effects still show on top
        containerView.addSubview(overlay, positioned: .below, relativeTo: effectsView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),

            helpContent.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            helpContent.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 60),
            helpContent.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -60),

            arrowLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            arrowLabel.topAnchor.constraint(equalTo: helpContent.bottomAnchor, constant: 24),

            dismissLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dismissLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24),
        ])

        helpOverlay = overlay

        // Show arrow window pointing to the status bar icon
        showSettingsArrowToStatusItem()
    }

    private func showSettingsArrowToStatusItem() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        guard let screen = NSScreen.main else { return }
        guard let popupWindow = self.view.window else { return }

        if let statusFrame = appDelegate.statusItemFrame() {
            // We have a reliable status item position — draw the arrow directly to it
            let popupFrame = popupWindow.frame

            let startX = popupFrame.midX
            let startY = popupFrame.maxY
            let endX = statusFrame.midX
            let endY = statusFrame.minY

            let minX = min(startX, endX) - 30
            let maxX = max(startX, endX) + 30
            let minY = startY
            let maxY = endY + 10

            guard maxY > minY else { return }

            let arrowWindowFrame = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            let arrowWindow = NSWindow(
                contentRect: arrowWindowFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            arrowWindow.isOpaque = false
            arrowWindow.backgroundColor = .clear
            arrowWindow.ignoresMouseEvents = true
            arrowWindow.level = .floating
            arrowWindow.hasShadow = false

            let arrowView = SettingsArrowView(frame: NSRect(origin: .zero, size: arrowWindowFrame.size))
            arrowView.startPoint = CGPoint(x: startX - minX, y: 0)
            arrowView.endPoint = CGPoint(x: endX - minX, y: arrowWindowFrame.height)
            arrowView.arrowColor = retroGreen
            arrowWindow.contentView = arrowView

            arrowWindow.orderFront(nil)
            settingsArrowWindow = arrowWindow
        } else {
            // Fallback: draw a green underline across the entire menu bar area
            let menuBarHeight: CGFloat = NSStatusBar.system.thickness
            let lineHeight: CGFloat = 2.0
            let lineY = screen.frame.maxY - menuBarHeight - lineHeight

            let lineWindowFrame = NSRect(
                x: screen.frame.minX,
                y: lineY,
                width: screen.frame.width,
                height: lineHeight
            )

            let lineWindow = NSWindow(
                contentRect: lineWindowFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            lineWindow.isOpaque = false
            lineWindow.backgroundColor = .clear
            lineWindow.ignoresMouseEvents = true
            lineWindow.level = .floating
            lineWindow.hasShadow = false

            let lineView = MenuBarUnderlineView(frame: NSRect(origin: .zero, size: lineWindowFrame.size))
            lineView.lineColor = retroGreen
            lineWindow.contentView = lineView

            lineWindow.orderFront(nil)
            settingsArrowWindow = lineWindow
        }
    }

    func showMarkdownHelpScreen() {
        dismissHelp()
        showMarkdownHelp()
    }

    private func showMarkdownHelp() {
        let overlay = NSView(frame: containerView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.95).cgColor

        let titleFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 22, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let sectionFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let bodyFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .regular)
            : NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Back button
        let backButton = NSButton(title: "", target: self, action: #selector(markdownBackClicked))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        let backAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        backButton.attributedTitle = NSAttributedString(string: L.markdownHelpBack, attributes: backAttrs)
        backButton.setAccessibilityLabel(L.help)
        overlay.addSubview(backButton)

        // Content - left aligned reference material
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let leftPara = NSMutableParagraphStyle()
        leftPara.alignment = .left
        leftPara.lineSpacing = 4

        let sectionPara = NSMutableParagraphStyle()
        sectionPara.alignment = .left
        sectionPara.paragraphSpacingBefore = 16

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: titleFont,
            .paragraphStyle: leftPara
        ]
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.5),
            .font: sectionFont,
            .paragraphStyle: sectionPara
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen,
            .font: bodyFont,
            .paragraphStyle: leftPara
        ]
        let syntaxAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: bodyFont,
            .paragraphStyle: leftPara
        ]

        let str = NSMutableAttributedString()

        // Title
        str.append(NSAttributedString(string: L.markdownSupport.uppercased(), attributes: titleAttrs))

        // Keybindings section
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpBindings, attributes: sectionAttrs))
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpShiftEnterRich, attributes: bodyAttrs))
        str.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpShiftEnterPlain, attributes: bodyAttrs))

        // Cheat sheet section
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpCheatSheet, attributes: sectionAttrs))
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpHeadings, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpBold, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpItalic, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpCode, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpCodeBlock, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpLink, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpList, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpOrderedList, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpBlockquote, attributes: syntaxAttrs))
        str.append(NSAttributedString(string: "\n", attributes: syntaxAttrs))
        str.append(NSAttributedString(string: L.markdownHelpHr, attributes: syntaxAttrs))

        let helpContent = NSTextField(labelWithString: "")
        helpContent.translatesAutoresizingMaskIntoConstraints = false
        helpContent.backgroundColor = .clear
        helpContent.isBezeled = false
        helpContent.isEditable = false
        helpContent.maximumNumberOfLines = 0
        helpContent.lineBreakMode = .byWordWrapping
        helpContent.alignment = .left
        helpContent.attributedStringValue = str

        // Scroll view in case content is too tall
        let scrollContainer = NSScrollView()
        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.hasVerticalScroller = true
        scrollContainer.drawsBackground = false
        scrollContainer.scrollerStyle = .overlay
        scrollContainer.documentView = helpContent

        // Allow helpContent to expand in scrollContainer
        helpContent.setContentHuggingPriority(.defaultLow, for: .vertical)

        let dismissLabel = NSTextField(labelWithString: "")
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        dismissLabel.backgroundColor = .clear
        dismissLabel.isBezeled = false
        dismissLabel.isEditable = false
        dismissLabel.alignment = .center
        dismissLabel.attributedStringValue = makeDismissString(withBackNav: true)

        overlay.addSubview(scrollContainer)
        overlay.addSubview(dismissLabel)

        // Track focusable items for keyboard navigation
        helpFocusableItems = [backButton]
        helpFocusIndex = -1
        helpHasBackButton = true

        // Insert below effectsView so CRT effects still show on top
        containerView.addSubview(overlay, positioned: .below, relativeTo: effectsView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),

            scrollContainer.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            scrollContainer.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 60),
            scrollContainer.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -60),
            scrollContainer.bottomAnchor.constraint(equalTo: dismissLabel.topAnchor, constant: -16),

            helpContent.topAnchor.constraint(equalTo: scrollContainer.contentView.topAnchor),
            helpContent.leadingAnchor.constraint(equalTo: scrollContainer.contentView.leadingAnchor),
            helpContent.trailingAnchor.constraint(equalTo: scrollContainer.contentView.trailingAnchor),

            dismissLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dismissLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24),
        ])

        helpOverlay = overlay
    }

    private func showEditingHelp() {
        let overlay = NSView(frame: containerView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.95).cgColor

        let titleFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 22, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let sectionFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let bodyFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 14, weight: .regular)
            : NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Back button
        let backButton = NSButton(title: "", target: self, action: #selector(editingBackClicked))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        let backAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        backButton.attributedTitle = NSAttributedString(string: L.markdownHelpBack, attributes: backAttrs)
        backButton.setAccessibilityLabel(L.help)
        overlay.addSubview(backButton)

        // Content
        let leftPara = NSMutableParagraphStyle()
        leftPara.alignment = .left
        leftPara.lineSpacing = 4

        let sectionPara = NSMutableParagraphStyle()
        sectionPara.alignment = .left
        sectionPara.paragraphSpacingBefore = 16

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: titleFont,
            .paragraphStyle: leftPara
        ]
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.5),
            .font: sectionFont,
            .paragraphStyle: sectionPara
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen,
            .font: bodyFont,
            .paragraphStyle: leftPara
        ]

        let str = NSMutableAttributedString()

        // Title
        str.append(NSAttributedString(string: L.editing.uppercased(), attributes: titleAttrs))

        // Keybindings section
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.markdownHelpBindings, attributes: sectionAttrs))
        str.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.editingHelpCtrlEText, attributes: bodyAttrs))
        str.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        str.append(NSAttributedString(string: L.editingHelpCtrlEMultimedia, attributes: bodyAttrs))

        let helpContent = NSTextField(labelWithString: "")
        helpContent.translatesAutoresizingMaskIntoConstraints = false
        helpContent.backgroundColor = .clear
        helpContent.isBezeled = false
        helpContent.isEditable = false
        helpContent.maximumNumberOfLines = 0
        helpContent.lineBreakMode = .byWordWrapping
        helpContent.alignment = .left
        helpContent.attributedStringValue = str

        // See also: Markdown Support link
        let seeAlsoButton = NSButton(title: "", target: self, action: #selector(editingSeeMarkdownClicked))
        seeAlsoButton.translatesAutoresizingMaskIntoConstraints = false
        seeAlsoButton.isBordered = false
        let seeAlsoLinkAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        seeAlsoButton.attributedTitle = NSAttributedString(string: L.editingHelpSeeAlsoMarkdown, attributes: seeAlsoLinkAttrs)
        seeAlsoButton.setAccessibilityLabel(L.markdownSupport)

        // Vim toggle button
        let vimEnabled = UserDefaults.standard.bool(forKey: "vimModeEnabled")
        let vimToggleText = vimEnabled ? L.editingHelpVimDisable : L.editingHelpVimEnable
        let vimToggleButton = NSButton(title: "", target: self, action: #selector(editingVimToggleClicked))
        vimToggleButton.translatesAutoresizingMaskIntoConstraints = false
        vimToggleButton.isBordered = false
        let vimLinkAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: bodyFont,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        vimToggleButton.attributedTitle = NSAttributedString(string: vimToggleText, attributes: vimLinkAttrs)
        vimToggleButton.setAccessibilityLabel(vimToggleText)

        let dismissLabel = NSTextField(labelWithString: "")
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        dismissLabel.backgroundColor = .clear
        dismissLabel.isBezeled = false
        dismissLabel.isEditable = false
        dismissLabel.alignment = .center
        dismissLabel.attributedStringValue = makeDismissString(withBackNav: true)

        overlay.addSubview(helpContent)
        overlay.addSubview(seeAlsoButton)
        overlay.addSubview(vimToggleButton)
        overlay.addSubview(dismissLabel)

        // Track focusable items for keyboard navigation
        helpFocusableItems = [backButton, seeAlsoButton, vimToggleButton]
        helpFocusIndex = -1
        helpHasBackButton = true

        // Insert below effectsView so CRT effects still show on top
        containerView.addSubview(overlay, positioned: .below, relativeTo: effectsView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),

            helpContent.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            helpContent.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 60),
            helpContent.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -60),

            seeAlsoButton.topAnchor.constraint(equalTo: helpContent.bottomAnchor, constant: 16),
            seeAlsoButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 60),

            vimToggleButton.topAnchor.constraint(equalTo: seeAlsoButton.bottomAnchor, constant: 8),
            vimToggleButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 60),

            dismissLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dismissLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24),
        ])

        helpOverlay = overlay
    }

    private func makeHelpContent() -> NSAttributedString {
        let str = NSMutableAttributedString()
        let titleFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 24, weight: .bold)
            : NSFont(name: "Menlo-Bold", size: 20) ?? NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        let stepFont = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 18, weight: .regular)
            : NSFont(name: "Menlo", size: 16) ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

        let titlePara = NSMutableParagraphStyle()
        titlePara.alignment = .center

        let stepPara = NSMutableParagraphStyle()
        stepPara.alignment = .center
        stepPara.lineSpacing = 6
        stepPara.paragraphSpacingBefore = 16

        let subStepPara = NSMutableParagraphStyle()
        subStepPara.alignment = .center
        subStepPara.lineSpacing = 6
        subStepPara.paragraphSpacingBefore = 4

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: titleFont,
            .paragraphStyle: titlePara
        ]
        let stepAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen,
            .font: stepFont,
            .paragraphStyle: stepPara
        ]
        let stepKeyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen,
            .font: stepFont,
            .paragraphStyle: stepPara
        ]
        let subStepAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen,
            .font: stepFont,
            .paragraphStyle: subStepPara
        ]

        str.append(NSAttributedString(string: L.helpTitle, attributes: titleAttrs))

        str.append(NSAttributedString(string: "\n1.  ", attributes: stepKeyAttrs))
        str.append(NSAttributedString(string: L.helpStep1, attributes: stepAttrs))

        str.append(NSAttributedString(string: "\n2.  ", attributes: stepKeyAttrs))
        str.append(NSAttributedString(string: HotkeyChoice.current.displayName, attributes: stepKeyAttrs))
        str.append(NSAttributedString(string: " " + L.helpStep2Suffix, attributes: stepAttrs))

        str.append(NSAttributedString(string: "\n3.  ", attributes: stepKeyAttrs))
        str.append(NSAttributedString(string: L.helpStep3a, attributes: stepAttrs))
        str.append(NSAttributedString(string: "\n    ", attributes: subStepAttrs))
        str.append(NSAttributedString(string: L.helpStep3b, attributes: subStepAttrs))

        return str
    }

    private func makeDismissString(withBackNav: Bool = false) -> NSAttributedString {
        let font = L.current.usesSystemFont
            ? NSFont.systemFont(ofSize: 16, weight: .medium)
            : NSFont(name: "Menlo", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.5),
            .font: font,
            .paragraphStyle: centered
        ]
        let text = withBackNav ? L.helpNavHintBack : L.helpNavHint
        return NSAttributedString(string: text, attributes: attrs)
    }

    @objc private func clearSearchClicked() {
        searchField.stringValue = ""
        searchQuery = ""
        reloadEntries()
        view.window?.makeFirstResponder(self)
    }

    @objc private func accessibilityHintClicked() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            updateAccessibilityHint()
            return
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    private func updateAccessibilityHint() {
        accessibilityHintButton?.isHidden = AXIsProcessTrusted()
    }

    private func updatePermissionWarning() {
        let hasItems = !(clipboardManager?.entries.isEmpty ?? true)
        let shouldHide = AXIsProcessTrusted() || !hasItems
        permissionWarningButton?.isHidden = shouldHide
        if shouldHide {
            dismissPermissionTooltip()
        }
    }

    @objc private func permissionWarningClicked() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            updatePermissionWarning()
            return
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    private func showPermissionTooltip() {
        guard permissionTooltipView == nil else { return }

        let tooltip = NSView()
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.wantsLayer = true
        tooltip.layer?.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95).cgColor
        tooltip.layer?.borderColor = NSColor.orange.withAlphaComponent(0.4).cgColor
        tooltip.layer?.borderWidth = 1
        tooltip.layer?.cornerRadius = 4

        let label = NSTextField(labelWithString: L.permissionWarningTooltip)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = retroFontSmall
        label.textColor = NSColor.orange.withAlphaComponent(0.85)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 400

        tooltip.addSubview(label)
        containerView.addSubview(tooltip, positioned: .below, relativeTo: effectsView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -10),

            tooltip.bottomAnchor.constraint(equalTo: permissionWarningButton.topAnchor, constant: -4),
            tooltip.trailingAnchor.constraint(equalTo: permissionWarningButton.trailingAnchor),
        ])

        permissionTooltipView = tooltip
    }

    private func dismissPermissionTooltip() {
        permissionTooltipView?.removeFromSuperview()
        permissionTooltipView = nil
    }

    private func setupEmptyState() {
        emptyStateView = NSView(frame: .zero)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true

        let ascii = """
         _____ ____  _____ _____ ____   ___    _    ____  ____
        |  ___|  _ \\| ____| ____| __ ) / _ \\  / \\  |  _ \\|  _ \\
        | |_  | |_) |  _| |  _| |  _ \\| | | |/ _ \\ | |_) | | | |
        |  _| |  _ <| |___| |___| |_) | |_| / ___ \\|  _ <| |_| |
        |_|   |_| \\_\\_____|_____|____/ \\___/_/   \\_\\_| \\_\\____/
        """

        let asciiLabel = NSTextField(labelWithString: ascii)
        asciiLabel.translatesAutoresizingMaskIntoConstraints = false
        asciiLabel.font = NSFont(name: "Menlo", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        asciiLabel.textColor = retroGreen.withAlphaComponent(0.4)
        asciiLabel.backgroundColor = .clear
        asciiLabel.isBezeled = false
        asciiLabel.alignment = .center
        asciiLabel.maximumNumberOfLines = 0
        asciiLabel.lineBreakMode = .byClipping
        asciiLabel.tag = 102
        asciiLabel.setAccessibilityElement(false)

        let hintLabel = NSTextField(labelWithString: "")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = retroFont
        hintLabel.textColor = retroDimGreen.withAlphaComponent(0.5)
        hintLabel.backgroundColor = .clear
        hintLabel.isBezeled = false
        hintLabel.alignment = .center
        hintLabel.tag = 100 // tag for refreshLocalization

        let hotkeyLabel = NSTextField(labelWithString: "")
        hotkeyLabel.translatesAutoresizingMaskIntoConstraints = false
        hotkeyLabel.font = retroFontSmall
        hotkeyLabel.textColor = retroDimGreen.withAlphaComponent(0.35)
        hotkeyLabel.backgroundColor = .clear
        hotkeyLabel.isBezeled = false
        hotkeyLabel.alignment = .center
        hotkeyLabel.tag = 101 // tag for refreshLocalization

        clearSearchButton = NSButton(title: L.clearSearch, target: self, action: #selector(clearSearchClicked))
        clearSearchButton.translatesAutoresizingMaskIntoConstraints = false
        clearSearchButton.isBordered = false
        clearSearchButton.wantsLayer = true
        clearSearchButton.layer?.borderColor = retroDimGreen.withAlphaComponent(0.5).cgColor
        clearSearchButton.layer?.borderWidth = 1
        clearSearchButton.layer?.cornerRadius = 4
        clearSearchButton.font = retroFontSmall
        clearSearchButton.contentTintColor = retroGreen
        clearSearchButton.isHidden = true

        accessibilityHintButton = NSButton(title: "", target: self, action: #selector(accessibilityHintClicked))
        accessibilityHintButton.translatesAutoresizingMaskIntoConstraints = false
        accessibilityHintButton.isBordered = false
        accessibilityHintButton.wantsLayer = true
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.5),
            .font: retroFontSmall
        ]
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.7),
            .font: retroFontSmall,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let hintStr = NSMutableAttributedString()
        hintStr.append(NSAttributedString(string: "Auto-paste needs ", attributes: hintAttrs))
        hintStr.append(NSAttributedString(string: "Accessibility Permission", attributes: linkAttrs))
        hintStr.append(NSAttributedString(string: " to paste", attributes: hintAttrs))
        accessibilityHintButton.attributedTitle = hintStr
        accessibilityHintButton.isHidden = true

        emptyStateView.addSubview(asciiLabel)
        emptyStateView.addSubview(hintLabel)
        emptyStateView.addSubview(hotkeyLabel)
        emptyStateView.addSubview(clearSearchButton)
        emptyStateView.addSubview(accessibilityHintButton)
        containerView.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            asciiLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            asciiLabel.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -24),
            asciiLabel.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor, constant: 12),
            asciiLabel.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor, constant: -12),

            hintLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: 20),

            hotkeyLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            hotkeyLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),

            clearSearchButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            clearSearchButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 16),

            accessibilityHintButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            accessibilityHintButton.topAnchor.constraint(equalTo: hotkeyLabel.bottomAnchor, constant: 16),
        ])

        updateEmptyStateStrings()
    }

    private func updateEmptyStateStrings() {
        guard let emptyView = emptyStateView else { return }
        if let hintLabel = emptyView.viewWithTag(100) as? NSTextField {
            hintLabel.stringValue = L.emptyHint
            hintLabel.font = retroFont
        }
        if let hotkeyLabel = emptyView.viewWithTag(101) as? NSTextField {
            hotkeyLabel.stringValue = "\(HotkeyChoice.current.displayName): \(L.openClose)"
            hotkeyLabel.font = retroFontSmall
        }
    }

    private func updateEmptyStateVisibility() {
        let mode = EmptyStateMode.compute(
            filteredEntriesEmpty: filteredEntries.isEmpty,
            searchQueryEmpty: searchQuery.isEmpty
        )
        switch mode {
        case .hidden:
            emptyStateView?.isHidden = true
            scrollView?.isHidden = false
            searchField?.isHidden = false
        case .noItems:
            emptyStateView?.isHidden = false
            scrollView?.isHidden = true
            searchField?.isHidden = true
            if let asciiLabel = emptyStateView?.viewWithTag(102) {
                asciiLabel.isHidden = false
            }
            if let hintLabel = emptyStateView?.viewWithTag(100) as? NSTextField {
                hintLabel.stringValue = L.emptyHint
                hintLabel.font = retroFont
            }
            if let hotkeyLabel = emptyStateView?.viewWithTag(101) {
                hotkeyLabel.isHidden = false
            }
            clearSearchButton?.isHidden = true
            updateAccessibilityHint()
        case .noSearchResults:
            emptyStateView?.isHidden = false
            scrollView?.isHidden = true
            searchField?.isHidden = false
            if let asciiLabel = emptyStateView?.viewWithTag(102) {
                asciiLabel.isHidden = true
            }
            if let hintLabel = emptyStateView?.viewWithTag(100) as? NSTextField {
                hintLabel.stringValue = L.noMatchesFound
                let largeFont = L.current.usesSystemFont
                    ? NSFont.systemFont(ofSize: 28, weight: .regular)
                    : NSFont(name: "Menlo", size: 24) ?? NSFont.monospacedSystemFont(ofSize: 24, weight: .regular)
                hintLabel.font = largeFont
            }
            if let hotkeyLabel = emptyStateView?.viewWithTag(101) {
                hotkeyLabel.isHidden = true
            }
            clearSearchButton?.title = L.clearSearch
            clearSearchButton?.font = retroFont
            clearSearchButton?.isHidden = false
            accessibilityHintButton?.isHidden = true
        }
    }

    /// A tag constant for hint buttons that have no meaningful click action.
    private static let hintTagNoAction = 0
    private static let hintTagPaste = 1
    private static let hintTagRichPaste = 2
    private static let hintTagExpand = 3
    private static let hintTagEdit = 4
    private static let hintTagStar = 5
    private static let hintTagDelete = 6
    private static let hintTagNextItem = 7
    private static let hintTagPrevItem = 8

    /// Build a single clickable hint button: "⌘S star" or "Enter paste" etc.
    /// `shortcut` is the keyboard-shortcut text (rendered brighter), `label` is the
    /// description (rendered dimmer). When `tag != hintTagNoAction`, clicking the
    /// button triggers `helpHintClicked(_:)`.
    private func makeHintButton(shortcut: String, label: String, tag: Int) -> NSButton {
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let title = NSMutableAttributedString()
        title.append(NSAttributedString(string: shortcut + " ", attributes: keyAttrs))
        title.append(NSAttributedString(string: label, attributes: dimAttrs))

        let btn: NSButton
        if tag != Self.hintTagNoAction {
            btn = HoverUnderlineButton(title: "", target: self, action: #selector(helpHintClicked(_:)))
        } else {
            btn = NSButton(title: "", target: self, action: #selector(helpHintClicked(_:)))
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.isBordered = false
        btn.attributedTitle = title
        btn.tag = tag
        btn.setAccessibilityLabel("\(shortcut) \(label)")
        return btn
    }

    /// Spacing label between hint buttons (non-clickable).
    private func makeHintSpacer() -> NSView {
        let spacer = NSTextField(labelWithString: "  ")
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.font = retroFontSmall
        spacer.textColor = .clear
        spacer.backgroundColor = .clear
        spacer.isEditable = false
        spacer.isBezeled = false
        return spacer
    }

    /// Rebuild the help bar buttons for the currently-selected entry.
    private func populateHelpBar(for entry: ClipboardEntry? = nil) {
        // Remove old hint buttons
        for view in helpLabel.arrangedSubviews { helpLabel.removeArrangedSubview(view); view.removeFromSuperview() }

        // "1-9 pasteNth" — informational only (no single action to trigger)
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "1-9", label: L.pasteNth, tag: Self.hintTagNoAction))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // "Enter paste"
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "Enter", label: L.paste, tag: Self.hintTagPaste))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // Dynamic shift hint based on selected entry's format category
        if let entry = entry, entry.entryType == .text {
            switch entry.formatCategory {
            case .markdown:
                let shiftFont = L.current.usesSystemFont
                    ? NSFont.systemFont(ofSize: 18, weight: .medium)
                    : NSFont(name: "Menlo-Bold", size: 15) ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
                let shiftAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroGreen.withAlphaComponent(0.6),
                    .font: shiftFont,
                    .baselineOffset: -1
                ]
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroGreen.withAlphaComponent(0.6),
                    .font: retroFontSmall
                ]
                let dimAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
                    .font: retroFontSmall
                ]
                // Build the rich paste button with mixed attributes for the shift symbol
                let rpTitle = NSMutableAttributedString()
                rpTitle.append(NSAttributedString(string: "\u{21E7}", attributes: shiftAttrs))
                rpTitle.append(NSAttributedString(string: "Enter ", attributes: keyAttrs))
                rpTitle.append(NSAttributedString(string: L.richPaste, attributes: dimAttrs))
                let rpBtn = HoverUnderlineButton(title: "", target: self, action: #selector(helpHintClicked(_:)))
                rpBtn.translatesAutoresizingMaskIntoConstraints = false
                rpBtn.isBordered = false
                rpBtn.attributedTitle = rpTitle
                rpBtn.tag = Self.hintTagRichPaste
                rpBtn.setAccessibilityLabel("Shift+Enter \(L.richPaste)")
                helpLabel.addArrangedSubview(rpBtn)
                helpLabel.addArrangedSubview(makeHintSpacer())
            case .code:
                let shiftFont = L.current.usesSystemFont
                    ? NSFont.systemFont(ofSize: 18, weight: .medium)
                    : NSFont(name: "Menlo-Bold", size: 15) ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
                let shiftAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroGreen.withAlphaComponent(0.6),
                    .font: shiftFont,
                    .baselineOffset: -1
                ]
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroGreen.withAlphaComponent(0.6),
                    .font: retroFontSmall
                ]
                let dimAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
                    .font: retroFontSmall
                ]
                let rpTitle = NSMutableAttributedString()
                rpTitle.append(NSAttributedString(string: "\u{21E7}", attributes: shiftAttrs))
                rpTitle.append(NSAttributedString(string: "Enter ", attributes: keyAttrs))
                rpTitle.append(NSAttributedString(string: L.formattedPaste, attributes: dimAttrs))
                let rpBtn = HoverUnderlineButton(title: "", target: self, action: #selector(helpHintClicked(_:)))
                rpBtn.translatesAutoresizingMaskIntoConstraints = false
                rpBtn.isBordered = false
                rpBtn.attributedTitle = rpTitle
                rpBtn.tag = Self.hintTagRichPaste
                rpBtn.setAccessibilityLabel("Shift+Enter \(L.formattedPaste)")
                helpLabel.addArrangedSubview(rpBtn)
                helpLabel.addArrangedSubview(makeHintSpacer())
            case .other:
                break
            }
        }

        // "^N next" and "^P prev" — navigate the clipboard list
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "^N", label: L.select + "↓", tag: Self.hintTagNextItem))
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "^P", label: L.select + "↑", tag: Self.hintTagPrevItem))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // "Tab expand"
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "Tab", label: L.expand, tag: Self.hintTagExpand))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // "^E edit/view"
        let editOrView: String
        if let entry = entry, entry.entryType != .text {
            editOrView = L.view
        } else {
            editOrView = L.edit
        }
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "^E", label: editOrView, tag: Self.hintTagEdit))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // "⌘S star/unstar"
        let starText = entry?.isStarred == true ? L.unstar : L.star
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "\u{2318}S", label: starText, tag: Self.hintTagStar))
        helpLabel.addArrangedSubview(makeHintSpacer())

        // "⌘D delete"
        helpLabel.addArrangedSubview(makeHintButton(shortcut: "\u{2318}D", label: L.delete, tag: Self.hintTagDelete))
    }

    @objc private func helpHintClicked(_ sender: NSButton) {
        switch sender.tag {
        case Self.hintTagPaste:
            selectCurrent()
        case Self.hintTagRichPaste:
            selectCurrentAlternateFormat()
        case Self.hintTagExpand:
            toggleExpand()
        case Self.hintTagEdit:
            enterEditMode()
        case Self.hintTagStar:
            toggleStarOnSelected()
        case Self.hintTagDelete:
            deleteSelected()
        case Self.hintTagNextItem:
            moveSelection(by: 1)
        case Self.hintTagPrevItem:
            moveSelection(by: -1)
        default:
            break
        }
    }

    private func makeHelpButtonTitle() -> NSAttributedString {
        let str = NSMutableAttributedString()
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        str.append(NSAttributedString(string: "? ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.help + "  ", attributes: dimAttrs))
        return str
    }

    private func makeEscCloseButtonTitle() -> NSAttributedString {
        let str = NSMutableAttributedString()
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.close, attributes: dimAttrs))
        return str
    }

    private func updateHelpLabel() {
        let entry = filteredEntries.indices.contains(selectedIndex) ? filteredEntries[selectedIndex] : nil
        populateHelpBar(for: entry)

        // Update VoiceOver label for the help bar
        if let entry = entry, entry.entryType == .text {
            switch entry.formatCategory {
            case .markdown:
                helpLabel.setAccessibilityLabel(L.accessibilityMarkdownText)
            case .code:
                helpLabel.setAccessibilityLabel(L.accessibilityCodeText)
            case .other:
                helpLabel.setAccessibilityLabel(nil)
            }
        } else {
            helpLabel.setAccessibilityLabel(nil)
        }
    }

    // MARK: - Data

    func reloadEntries() {
        guard let manager = clipboardManager else { return }
        if searchQuery.isEmpty {
            let starred = manager.entries.filter { $0.isStarred }
            let unstarred = manager.entries.filter { !$0.isStarred }
            filteredEntries = starred + unstarred
        } else {
            filteredEntries = FuzzySearch.filter(entries: manager.entries, query: searchQuery)
        }
        selectedIndex = min(selectedIndex, max(filteredEntries.count - 1, 0))
        tableView?.reloadData()
        if !filteredEntries.isEmpty {
            tableView?.scrollRowToVisible(selectedIndex)
        }
        updateEmptyStateVisibility()
        updatePermissionWarning()
        updateHelpLabel()
    }    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredEntries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredEntries.count else { return nil }
        let entry = filteredEntries[row]
        let isSelected = row == selectedIndex
        let isExpanded = row == expandedIndex
        let isEditing = row == editingIndex

        let rowHeight = self.tableView(tableView, heightOfRow: row)
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: rowHeight))
        cell.wantsLayer = true
        cell.layer?.backgroundColor = isSelected ? retroSelectionBg.cgColor : NSColor.clear.cgColor
        cell.setAccessibilityRole(.row)
        cell.setAccessibilityRoleDescription("clipboard entry")

        // Communicate format category to VoiceOver
        if entry.entryType == .text {
            switch entry.formatCategory {
            case .markdown:
                cell.setAccessibilityHelp(L.accessibilityMarkdownText)
            case .code:
                cell.setAccessibilityHelp(L.accessibilityCodeText)
            case .other:
                break
            }
        }

        let indicatorTitle: String
        if entry.isStarred {
            indicatorTitle = "★"
        } else if row == hoveredRow && mouseInIndicatorZone {
            indicatorTitle = "☆"
        } else if isEditing {
            indicatorTitle = "✎"
        } else if isSelected {
            indicatorTitle = ">"
        } else {
            indicatorTitle = " "
        }

        let indicator = NSButton(title: indicatorTitle, target: self, action: #selector(starClicked(_:)))
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isBordered = false
        indicator.font = retroFontStar
        indicator.contentTintColor = retroGreen
        indicator.tag = row
        indicator.setAccessibilityLabel(entry.isStarred ? L.accessibilityStarred : L.accessibilityStar)
        cell.addSubview(indicator)

        // Number label for quick-select (rows 0–8 → keys 1–9)
        let numberLabel: NSTextField?
        if row < 9 {
            let nl = NSTextField(labelWithString: "[\(row + 1)]")
            nl.translatesAutoresizingMaskIntoConstraints = false
            nl.font = retroFontSmall
            nl.textColor = retroGreen.withAlphaComponent(0.7)
            nl.backgroundColor = .clear
            nl.isBezeled = false
            nl.setAccessibilityElement(false)
            cell.addSubview(nl)
            numberLabel = nl
        } else {
            numberLabel = nil
        }

        // Format indicator — subtle tag for markdown/code entries
        let mdLabel: NSTextField?
        let formatTag: String?
        switch entry.formatCategory {
        case .markdown:
            formatTag = "md"
        case .code(let lang):
            formatTag = lang
        case .other:
            formatTag = nil
        }
        if let tag = formatTag {
            let ml = NSTextField(labelWithString: tag)
            ml.translatesAutoresizingMaskIntoConstraints = false
            ml.font = retroFontSmall
            ml.textColor = retroDimGreen.withAlphaComponent(0.35)
            ml.backgroundColor = .clear
            ml.isBezeled = false
            ml.alignment = .right
            ml.setAccessibilityElement(false)
            cell.addSubview(ml)
            mdLabel = ml
        } else {
            mdLabel = nil
        }

        let timeLabel = NSTextField(labelWithString: entry.timeAgo)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = retroFontSmall
        timeLabel.textColor = retroDimGreen.withAlphaComponent(0.6)
        timeLabel.backgroundColor = .clear
        timeLabel.isBezeled = false
        timeLabel.alignment = .right
        timeLabel.setAccessibilityLabel(entry.accessibleTimeAgo)
        cell.addSubview(timeLabel)

        let deleteButton = NSButton(title: "×", target: self, action: #selector(deleteClicked(_:)))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isBordered = false
        deleteButton.font = NSFont(name: "Menlo", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        deleteButton.contentTintColor = retroDimGreen.withAlphaComponent(0.5)
        deleteButton.tag = row
        deleteButton.setAccessibilityLabel(L.accessibilityDelete)
        cell.addSubview(deleteButton)

        if isEditing {
            let scrollContainer = NSScrollView(frame: .zero)
            scrollContainer.translatesAutoresizingMaskIntoConstraints = false
            scrollContainer.hasVerticalScroller = true
            scrollContainer.drawsBackground = false
            scrollContainer.scrollerStyle = .overlay

            let tv = NSTextView()
            tv.font = retroFont
            tv.textColor = retroGreen
            tv.backgroundColor = NSColor(red: 0.05, green: 0.08, blue: 0.05, alpha: 0.9)
            tv.insertionPointColor = retroGreen
            tv.isEditable = true
            tv.isSelectable = true
            tv.isRichText = false
            tv.string = entry.content
            tv.delegate = self
            tv.isAutomaticQuoteSubstitutionEnabled = false
            tv.isAutomaticDashSubstitutionEnabled = false
            tv.isAutomaticTextReplacementEnabled = false
            tv.textContainerInset = NSSize(width: 4, height: 4)
            scrollContainer.documentView = tv
            self.editTextView = tv

            cell.addSubview(scrollContainer)

            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 34),
                indicator.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                indicator.widthAnchor.constraint(equalToConstant: 24),

                scrollContainer.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                scrollContainer.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                scrollContainer.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),

                timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                timeLabel.widthAnchor.constraint(equalToConstant: 70),

                deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                deleteButton.widthAnchor.constraint(equalToConstant: 24),
                deleteButton.heightAnchor.constraint(equalToConstant: 24)
            ])

            if let ml = mdLabel {
                NSLayoutConstraint.activate([
                    ml.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -4),
                    ml.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
                    scrollContainer.trailingAnchor.constraint(equalTo: ml.leadingAnchor, constant: -6),
                ])
            } else {
                scrollContainer.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10).isActive = true
            }

            if let nl = numberLabel {
                NSLayoutConstraint.activate([
                    nl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                    nl.centerYAnchor.constraint(equalTo: indicator.centerYAnchor),
                ])
            }

            // Focus the text view after layout
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
                tv.selectAll(nil)
            }
        } else {
            // Image view for image/fileURL entries
            var imageView: NSImageView? = nil
            if entry.entryType == .image, let data = entry.imageData, let image = NSImage(data: data) {
                let iv = NSImageView()
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.image = image
                iv.imageScaling = .scaleProportionallyUpOrDown
                iv.wantsLayer = true
                iv.layer?.cornerRadius = 4
                iv.layer?.borderColor = retroDimGreen.withAlphaComponent(0.3).cgColor
                iv.layer?.borderWidth = 1
                cell.addSubview(iv)
                imageView = iv
            } else if entry.entryType == .fileURL {
                let iv = NSImageView()
                iv.translatesAutoresizingMaskIntoConstraints = false
                if let url = entry.fileURL {
                    iv.image = NSWorkspace.shared.icon(forFile: url.path)
                } else {
                    iv.image = NSWorkspace.shared.icon(for: .item)
                }
                iv.imageScaling = .scaleProportionallyUpOrDown
                cell.addSubview(iv)
                imageView = iv
            }

            let contentLabel = NSTextField(labelWithString: "")
            contentLabel.translatesAutoresizingMaskIntoConstraints = false
            contentLabel.font = retroFont
            contentLabel.textColor = isSelected ? retroGreen : retroDimGreen
            contentLabel.backgroundColor = .clear
            contentLabel.isBezeled = false

            if isExpanded {
                contentLabel.lineBreakMode = .byWordWrapping
                contentLabel.maximumNumberOfLines = 0
                contentLabel.stringValue = entry.displayContent
            } else {
                contentLabel.lineBreakMode = .byTruncatingTail
                contentLabel.maximumNumberOfLines = 1
                let displayText = entry.displayContent
                    .replacingOccurrences(of: "\n", with: "\u{21B5} ")
                    .replacingOccurrences(of: "\t", with: "\u{2192} ")
                contentLabel.stringValue = displayText
            }

            if entry.entryType == .image {
                contentLabel.setAccessibilityLabel(entry.content.isEmpty ? L.imageEntry : entry.content)
            } else if entry.entryType == .fileURL {
                contentLabel.setAccessibilityLabel(entry.displayContent)
            } else {
                contentLabel.setAccessibilityLabel(entry.isPassword ? L.accessibilityPasswordHidden : entry.content)
            }
            cell.addSubview(contentLabel)

            if let iv = imageView {
                if isExpanded && entry.entryType == .image, let data = entry.imageData, let img = NSImage(data: data) {
                    // Large Quick Look-style display for expanded images
                    let maxW: CGFloat = tableView.bounds.width - 80
                    let maxH: CGFloat = 600
                    let ratio = min(maxW / img.size.width, maxH / img.size.height, 1.0)
                    let imgW = img.size.width * ratio
                    let imgH = img.size.height * ratio

                    NSLayoutConstraint.activate([
                        indicator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 34),
                        indicator.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                        indicator.widthAnchor.constraint(equalToConstant: 24),

                        iv.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                        iv.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                        iv.widthAnchor.constraint(equalToConstant: imgW),
                        iv.heightAnchor.constraint(equalToConstant: imgH),

                        contentLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                        contentLabel.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 4),

                        timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                        timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                        timeLabel.widthAnchor.constraint(equalToConstant: 70),

                        deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                        deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                        deleteButton.widthAnchor.constraint(equalToConstant: 24),
                        deleteButton.heightAnchor.constraint(equalToConstant: 24)
                    ])
                } else {
                    let thumbSize: CGFloat = 36

                    NSLayoutConstraint.activate([
                        indicator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 34),
                        indicator.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                        indicator.widthAnchor.constraint(equalToConstant: 24),

                        iv.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                        iv.topAnchor.constraint(equalTo: cell.topAnchor, constant: 7),
                        iv.widthAnchor.constraint(equalToConstant: thumbSize),
                        iv.heightAnchor.constraint(equalToConstant: thumbSize),

                        contentLabel.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 8),
                        contentLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                        contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -8),

                        timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                        timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                        timeLabel.widthAnchor.constraint(equalToConstant: 70),

                        deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                        deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                        deleteButton.widthAnchor.constraint(equalToConstant: 24),
                        deleteButton.heightAnchor.constraint(equalToConstant: 24)
                    ])
                }
            } else {
                NSLayoutConstraint.activate([
                    indicator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 34),
                    indicator.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                    indicator.widthAnchor.constraint(equalToConstant: 24),

                    contentLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                    contentLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                    contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -8),

                    timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                    timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                    timeLabel.widthAnchor.constraint(equalToConstant: 70),

                    deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                    deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                    deleteButton.widthAnchor.constraint(equalToConstant: 24),
                    deleteButton.heightAnchor.constraint(equalToConstant: 24)
                ])
            }

            // Connect content label trailing to md label or time label
            if let ml = mdLabel {
                NSLayoutConstraint.activate([
                    ml.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -4),
                    ml.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
                    contentLabel.trailingAnchor.constraint(equalTo: ml.leadingAnchor, constant: -6),
                ])
            } else {
                contentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10).isActive = true
            }

            if let nl = numberLabel {
                NSLayoutConstraint.activate([
                    nl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                    nl.centerYAnchor.constraint(equalTo: indicator.centerYAnchor),
                ])
            }

            // Stats label on expanded rows
            if isExpanded {
                let statsText: String
                let accessibleStats: String
                switch entry.entryType {
                case .text:
                    let charCount = entry.content.count
                    let wordCount = entry.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                    statsText = "\(charCount)c \(wordCount)w"
                    accessibleStats = "\(charCount) characters, \(wordCount) words"
                case .image:
                    if let data = entry.imageData, let image = NSImage(data: data) {
                        let w = Int(image.size.width)
                        let h = Int(image.size.height)
                        statsText = "\(w)×\(h)"
                        accessibleStats = "\(w) by \(h) pixels"
                    } else {
                        statsText = ""
                        accessibleStats = ""
                    }
                case .fileURL:
                    if let url = entry.fileURL,
                       let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? UInt64 {
                        statsText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                        accessibleStats = statsText
                    } else {
                        statsText = ""
                        accessibleStats = ""
                    }
                }

                if !statsText.isEmpty {
                    let statsLabel = NSTextField(labelWithString: statsText)
                    statsLabel.translatesAutoresizingMaskIntoConstraints = false
                    statsLabel.font = retroFontSmall
                    statsLabel.textColor = retroDimGreen.withAlphaComponent(0.4)
                    statsLabel.backgroundColor = .clear
                    statsLabel.isBezeled = false
                    statsLabel.alignment = .right
                    statsLabel.setAccessibilityLabel(accessibleStats)
                    cell.addSubview(statsLabel)

                    NSLayoutConstraint.activate([
                        statsLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                        statsLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
                    ])
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < filteredEntries.count else { return 50 }
        if row == editingIndex {
            let entry = filteredEntries[row]
            let maxWidth = tableView.bounds.width - 140
            let text = entry.content as NSString
            let boundingRect = text.boundingRect(
                with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: retroFont]
            )
            return max(80, min(ceil(boundingRect.height) + 30, 300))
        }
        guard row == expandedIndex else { return 50 }
        let entry = filteredEntries[row]
        if entry.entryType == .image {
            if let data = entry.imageData, let image = NSImage(data: data) {
                let maxW: CGFloat = tableView.bounds.width - 80
                let maxH: CGFloat = 600
                let ratio = min(maxW / image.size.width, maxH / image.size.height, 1.0)
                let imgH = image.size.height * ratio
                return max(50, imgH + 40)  // 40 for padding
            }
            return 220
        }
        let maxWidth = tableView.bounds.width - 140
        let text = entry.displayContent as NSString
        let boundingRect = text.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: retroFont]
        )
        return max(50, ceil(boundingRect.height) + 24)
    }

    // MARK: - Actions

    @objc private func deleteClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        historyDelegate?.didDeleteEntry(filteredEntries[row])
    }

    @objc private func starClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        clipboardManager?.toggleStar(id: filteredEntries[row].id)
    }

    private func toggleStarOnSelected() {
        guard selectedIndex < filteredEntries.count else { return }
        clipboardManager?.toggleStar(id: filteredEntries[selectedIndex].id)
    }

    private func deleteSelected() {
        guard selectedIndex < filteredEntries.count else { return }
        historyDelegate?.didDeleteEntry(filteredEntries[selectedIndex])
    }

    // MARK: - Context menu actions

    @objc private func contextMenuPaste(_ sender: NSMenuItem) {
        selectCurrent(at: sender.tag)
    }

    @objc private func contextMenuPasteAlternate(_ sender: NSMenuItem) {
        selectCurrentAlternateFormat(at: sender.tag)
    }

    @objc private func contextMenuEdit(_ sender: NSMenuItem) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        selectedIndex = row
        enterEditMode()
    }

    @objc private func contextMenuToggleExpand(_ sender: NSMenuItem) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        selectedIndex = row
        toggleExpand()
    }

    @objc private func contextMenuToggleStar(_ sender: NSMenuItem) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        clipboardManager?.toggleStar(id: filteredEntries[row].id)
    }

    @objc private func contextMenuDelete(_ sender: NSMenuItem) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        historyDelegate?.didDeleteEntry(filteredEntries[row])
    }

    @objc private func contextMenuRevealInFinder(_ sender: NSMenuItem) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        guard let url = filteredEntries[row].fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    override func mouseMoved(with event: NSEvent) {
        let pointInTable = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: pointInTable)
        let inIndicator = pointInTable.x < 60

        let oldRow = hoveredRow
        let oldZone = mouseInIndicatorZone
        hoveredRow = row >= 0 ? row : nil
        mouseInIndicatorZone = inIndicator

        if hoveredRow != oldRow || mouseInIndicatorZone != oldZone {
            var rowsToReload = IndexSet()
            if let old = oldRow { rowsToReload.insert(old) }
            if let new = hoveredRow { rowsToReload.insert(new) }
            if !rowsToReload.isEmpty {
                tableView.reloadData(forRowIndexes: rowsToReload, columnIndexes: IndexSet(integer: 0))
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let zone = event.trackingArea?.userInfo?["zone"] as? String, zone == "permissionWarning" {
            dismissPermissionTooltip()
            return
        }
        let oldRow = hoveredRow
        hoveredRow = nil
        mouseInIndicatorZone = false
        if let old = oldRow {
            tableView.reloadData(forRowIndexes: IndexSet(integer: old), columnIndexes: IndexSet(integer: 0))
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if let zone = event.trackingArea?.userInfo?["zone"] as? String, zone == "permissionWarning" {
            showPermissionTooltip()
            return
        }
        super.mouseEntered(with: event)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if editingIndex != nil || monacoEditorView != nil { return }

        let row = tableView.clickedRow
        guard row >= 0, row < filteredEntries.count else { return }

        let entry = filteredEntries[row]

        selectedIndex = row
        tableView.reloadData()
        updateHelpLabel()

        func addItem(_ title: String, hint: String? = nil, action: Selector) {
            let label = hint != nil ? "\(title)  (\(hint!))" : title
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.tag = row
            item.target = self
            menu.addItem(item)
        }

        addItem(L.contextPaste, hint: "Enter", action: #selector(contextMenuPaste(_:)))

        if entry.entryType == .text && !entry.isPassword {
            switch entry.formatCategory {
            case .markdown:
                addItem(L.contextPasteAsRichText, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
            case .code:
                addItem(L.contextPasteFormatted, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
            case .other:
                if entry.hasRichData {
                    addItem(L.contextPasteAsPlainText, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
                }
            }
        }

        menu.addItem(NSMenuItem.separator())

        if entry.entryType == .text && !entry.isPassword {
            addItem(L.contextEdit, hint: "^E", action: #selector(contextMenuEdit(_:)))
        } else if entry.entryType == .image || entry.entryType == .fileURL {
            addItem(L.contextView, hint: "^E", action: #selector(contextMenuEdit(_:)))
        }

        let expandTitle = expandedIndex == row ? L.contextCollapse : L.contextExpand
        addItem(expandTitle, hint: "Tab", action: #selector(contextMenuToggleExpand(_:)))

        let starTitle = entry.isStarred ? L.contextUnstar : L.contextStar
        addItem(starTitle, hint: "⌘S", action: #selector(contextMenuToggleStar(_:)))

        menu.addItem(NSMenuItem.separator())

        if entry.entryType == .fileURL, entry.fileURL != nil {
            addItem(L.contextRevealInFinder, action: #selector(contextMenuRevealInFinder(_:)))
        }

        addItem(L.contextDelete, hint: "⌘D", action: #selector(contextMenuDelete(_:)))
    }

    @objc private func tableClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredEntries.count else { return }
        selectedIndex = row
        handleEnter()
    }

    private func handleEnter() {
        if editingIndex != nil || monacoEditorView != nil { return }
        selectCurrent()
    }

    private func selectCurrent(at index: Int? = nil) {
        let idx = index ?? selectedIndex
        guard idx < filteredEntries.count else { return }
        historyDelegate?.didSelectEntry(filteredEntries[idx])
    }

    /// Shift+Enter / Shift+N: paste in the "alternative" format.
    /// For rich text → plain, for plain markdown → rich, for rich markdown → markdown source.
    /// For code → syntax-highlighted rich text.
    private func selectCurrentAlternateFormat(at index: Int? = nil) {
        let idx = index ?? selectedIndex
        guard idx < filteredEntries.count else { return }
        let entry = filteredEntries[idx]
        switch entry.formatCategory {
        case .markdown:
            historyDelegate?.didSelectEntryAsRenderedMarkdown(entry)
        case .code(let language):
            historyDelegate?.didSelectEntryAsSyntaxHighlightedCode(entry, language: language)
        case .other:
            historyDelegate?.didSelectEntryAsPlainText(entry)
        }
    }

    private func toggleExpand() {
        guard !filteredEntries.isEmpty else { return }
        if editingIndex != nil || monacoEditorView != nil { return } // Don't toggle while editing
        if expandedIndex == selectedIndex {
            expandedIndex = nil
        } else {
            expandedIndex = selectedIndex
        }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: selectedIndex))
        tableView.reloadData()
        tableView.scrollRowToVisible(selectedIndex)
    }

    /// View an image entry by writing a temporary file and opening it with the system viewer.
    /// The temp file is cleaned up after a short delay to honor the "instant and ephemeral" principle.
    private func viewImageEntry(_ entry: ClipboardEntry) {
        guard let data = entry.imageData else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "freeboard_preview_\(entry.id.uuidString).png"
        let tempURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
            // Clean up the temp file after a delay to give the viewer time to open
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch {
            // Silently fail — no beep, no disk write noise
        }
    }

    /// View a file entry by revealing it in Finder or opening it with the system viewer.
    private func viewFileEntry(_ entry: ClipboardEntry) {
        guard let url = entry.fileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func enterEditMode() {
        guard selectedIndex < filteredEntries.count else { return }
        let entry = filteredEntries[selectedIndex]
        guard !entry.isPassword else { return }

        switch entry.entryType {
        case .image:
            viewImageEntry(entry)
            return
        case .fileURL:
            viewFileEntry(entry)
            return
        case .text:
            break // fall through to Monaco editor
        }

        monacoEditingIndex = selectedIndex

        // Reuse preloaded editor or create a new one
        let editorView: MonacoEditorView
        if let preloaded = preloadedMonacoEditor {
            editorView = preloaded
            preloadedMonacoEditor = nil
            editorView.removeFromSuperview()
            editorView.frame = .zero
        } else {
            editorView = MonacoEditorView(frame: .zero)
            editorView.loadEditor()
        }

        editorView.translatesAutoresizingMaskIntoConstraints = false
        editorView.delegate = self
        editorView.wantsLayer = true
        editorView.layer?.cornerRadius = 4
        editorView.isHidden = false
        editorView.setAccessibilityIdentifier("MonacoEditor")

        containerView.addSubview(editorView, positioned: .above, relativeTo: effectsView)
        effectsView.isHidden = true

        NSLayoutConstraint.activate([
            editorView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            editorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            editorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            editorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
        ])

        // Hide other elements
        scrollView.isHidden = true
        searchField.isHidden = true
        helpLabel.isHidden = true
        helpButton.isHidden = true
        escCloseButton.isHidden = true
        permissionWarningButton.isHidden = true
        dismissPermissionTooltip()
        emptyStateView?.isHidden = true

        monacoEditorView = editorView

        let language = MonacoEditorView.detectLanguage(entry.content)
        editorView.setContent(entry.content, language: language)

        // Ensure WKWebView gets keyboard focus after layout pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            editorView.focusEditor()
        }
    }

    private func exitEditMode() {
        // Monaco editor path
        if let editorView = monacoEditorView {
            editorView.cleanup()
            editorView.removeFromSuperview()
            monacoEditorView = nil
            monacoEditingIndex = nil
            effectsView.isHidden = false

            // Preload a fresh editor for next time
            if preloadedMonacoEditor == nil {
                preloadMonacoEditor()
            }

            // Restore UI elements
            scrollView.isHidden = false
            searchField.isHidden = false
            helpLabel.isHidden = false
            helpButton.isHidden = false
            escCloseButton.isHidden = false
            updateEmptyStateVisibility()
            updatePermissionWarning()

            reloadEntries()
            view.window?.makeFirstResponder(self)
            return
        }

        // Legacy inline edit path
        guard let idx = editingIndex, idx < filteredEntries.count else {
            editingIndex = nil
            editTextView = nil
            return
        }
        if let tv = editTextView {
            let newContent = tv.string
            if !newContent.isEmpty && newContent != filteredEntries[idx].content {
                clipboardManager?.updateEntryContent(id: filteredEntries[idx].id, newContent: newContent)
            }
        }
        editingIndex = nil
        editTextView = nil
        reloadEntries()
        view.window?.makeFirstResponder(self)
    }

    // MARK: - MonacoEditorDelegate

    func editorDidSave(content: String) {
        if let idx = monacoEditingIndex, idx < filteredEntries.count {
            let entry = filteredEntries[idx]
            if !content.isEmpty && content != entry.content {
                clipboardManager?.updateEntryContent(id: entry.id, newContent: content)
            }
        }
        exitEditMode()
    }

    func editorDidClose() {
        exitEditMode()
    }

    // MARK: - Keyboard handling

    private var isSearchFieldFocused: Bool {
        view.window?.firstResponder === searchField.currentEditor()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 { // Esc
            if helpOverlay?.superview != nil {
                dismissHelp()
            } else if monacoEditorView != nil {
                monacoEditorView?.triggerSaveAndClose()
            } else if editingIndex != nil {
                exitEditMode()
            } else if isSearchFieldFocused {
                searchField.stringValue = ""
                searchQuery = ""
                reloadEntries()
                view.window?.makeFirstResponder(self)
            } else {
                historyDelegate?.didDismiss()
            }
            return
        }

        // Help overlay keyboard navigation
        if helpOverlay?.superview != nil {
            if let chars = event.charactersIgnoringModifiers {
                if chars == "j" && flags.isEmpty {
                    helpMoveFocus(by: 1)
                    return
                }
                if chars == "k" && flags.isEmpty {
                    helpMoveFocus(by: -1)
                    return
                }
                // Ctrl+] — vim help jump (secret alias for Enter)
                if chars == "]" && flags == .control {
                    helpActivateFocused()
                    return
                }
            }
            // Enter follows highlighted link
            if event.keyCode == 36 && flags.isEmpty {
                helpActivateFocused()
                return
            }
            // Backspace goes back on sub-screens
            if event.keyCode == 51 && helpHasBackButton {
                helpGoBack()
                return
            }
            // Arrow keys also work for navigation
            if event.keyCode == 125 { helpMoveFocus(by: 1); return } // Down
            if event.keyCode == 126 { helpMoveFocus(by: -1); return } // Up
            // Swallow all other keys while help is open
            return
        }

        if event.keyCode == 36 { // Enter
            if editingIndex != nil { return } // Let text view handle it
            if event.modifierFlags.contains(.shift) {
                selectCurrentAlternateFormat()
            } else {
                handleEnter()
            }
            return
        }
        if monacoEditorView != nil {
            return // Native editor handles its own keys
        }
        if editingIndex != nil { super.keyDown(with: event); return } // Pass through when editing

        // Normal mode (search field NOT focused): number keys quick select
        if !isSearchFieldFocused {
            if let chars = event.charactersIgnoringModifiers, let digit = chars.first, digit >= "1" && digit <= "9" {
                let index = Int(String(digit))! - 1
                if flags == .shift {
                    selectCurrentAlternateFormat(at: index)
                } else if flags.isEmpty {
                    selectCurrent(at: index)
                }
                return
            }
        }

        if event.keyCode == 48 { toggleExpand(); return } // Tab
        if flags.contains(.control) && event.charactersIgnoringModifiers == "e" { enterEditMode(); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "n" { moveSelection(by: 1); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "p" { moveSelection(by: -1); return }
        if event.keyCode == 125 { moveSelection(by: 1); return }
        if event.keyCode == 126 { moveSelection(by: -1); return }

        // Delete/Backspace: refocus search field if there's an active search query
        if event.keyCode == 51, !isSearchFieldFocused, !searchQuery.isEmpty { // 51 = Delete/Backspace
            view.window?.makeFirstResponder(searchField)
            searchField.currentEditor()?.moveToEndOfLine(nil)
            searchField.currentEditor()?.deleteBackward(nil)
            return
        }

        // ? key toggles help overlay
        if let chars = event.characters, chars == "?", flags.isEmpty || flags == .shift {
            toggleHelp()
            return
        }

        // Type-ahead: any printable character focuses the search field and starts a search
        // Skip when clipboard history is empty — there's nothing to search
        if !isSearchFieldFocused,
           !(clipboardManager?.entries.isEmpty ?? true),
           let chars = event.characters,
           let first = chars.unicodeScalars.first,
           flags.isEmpty || flags == .shift,
           !CharacterSet.controlCharacters.contains(first) {
            view.window?.makeFirstResponder(searchField)
            searchField.currentEditor()?.insertText(chars)
            return
        }

        super.keyDown(with: event)
    }

    private func moveSelection(by delta: Int) {
        guard !filteredEntries.isEmpty else { return }
        let oldExpanded = expandedIndex
        selectedIndex = max(0, min(filteredEntries.count - 1, selectedIndex + delta))
        if expandedIndex != nil && expandedIndex != selectedIndex {
            expandedIndex = nil
            if let old = oldExpanded {
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: old))
            }
        }
        tableView.reloadData()
        tableView.scrollRowToVisible(selectedIndex)
        updateHelpLabel()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        // ? toggles help even when search field is focused
        if searchField.stringValue.hasSuffix("?") {
            let withoutQuestion = String(searchField.stringValue.dropLast())
            searchField.stringValue = withoutQuestion
            searchQuery = withoutQuestion
            if searchQuery.isEmpty {
                view.window?.makeFirstResponder(self)
            }
            reloadEntries()
            toggleHelp()
            return
        }
        searchQuery = searchField.stringValue
        selectedIndex = 0
        expandedIndex = nil
        reloadEntries()
        if searchQuery.isEmpty {
            view.window?.makeFirstResponder(self)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            if editingIndex != nil { return false } // Let text view handle newlines
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                selectCurrentAlternateFormat()
            } else {
                handleEnter()
            }
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            if editingIndex != nil {
                exitEditMode()
            } else if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                searchQuery = ""
                reloadEntries()
                view.window?.makeFirstResponder(self)
            } else {
                view.window?.makeFirstResponder(self)
                historyDelegate?.didDismiss()
            }
            return true
        }
        if editingIndex != nil { return false }
        if commandSelector == #selector(moveDown(_:)) {
            view.window?.makeFirstResponder(self)
            moveSelection(by: 1)
            return true
        }
        if commandSelector == #selector(moveUp(_:)) {
            view.window?.makeFirstResponder(self)
            moveSelection(by: -1)
            return true
        }
        if commandSelector == #selector(insertTab(_:)) { toggleExpand(); return true }
        if commandSelector == #selector(moveToEndOfParagraph(_:)) { enterEditMode(); return true } // ctrl-e
        return false
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            exitEditMode()
            return true
        }
        return false
    }
}

// MARK: - Settings Arrow View

class SettingsArrowView: NSView {
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    var arrowColor: NSColor = NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw a dashed line from start to end
        context.setStrokeColor(arrowColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.setLineCap(.round)

        context.beginPath()
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // Draw arrowhead at the end (pointing up)
        let arrowSize: CGFloat = 12
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowAngle: CGFloat = .pi / 6

        let leftPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle - arrowAngle),
            y: endPoint.y - arrowSize * sin(angle - arrowAngle)
        )
        let rightPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle + arrowAngle),
            y: endPoint.y - arrowSize * sin(angle + arrowAngle)
        )

        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(arrowColor.withAlphaComponent(0.6).cgColor)
        context.beginPath()
        context.move(to: endPoint)
        context.addLine(to: leftPoint)
        context.addLine(to: rightPoint)
        context.closePath()
        context.fillPath()
    }
}

// MARK: - Menu Bar Underline View

class MenuBarUnderlineView: NSView {
    var lineColor: NSColor = NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(lineColor.withAlphaComponent(0.6).cgColor)
        context.fill(bounds)
    }
}
