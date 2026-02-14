import Cocoa
import WebKit

protocol ClipboardHistoryDelegate: AnyObject {
    func didSelectEntry(_ entry: ClipboardEntry)
    func didSelectEntryAsPlainText(_ entry: ClipboardEntry)
    func didDeleteEntry(_ entry: ClipboardEntry)
    func didDismiss()
}

class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate, NSGestureRecognizerDelegate, MonacoEditorDelegate {

    weak var historyDelegate: ClipboardHistoryDelegate?
    var clipboardManager: ClipboardManager?

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var searchField: NSTextField!
    private var helpLabel: NSTextField!
    private var quitButton: NSButton!
    private var containerView: NSView!
    private var effectsView: RetroEffectsView!
    private var emptyStateView: NSView!
    private var clearSearchButton: NSButton!
    private var accessibilityHintButton: NSButton!
    private var permissionWarningButton: NSButton!
    private var helpButton: NSButton!
    private var helpOverlay: NSView?

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
    private var imageEditSource: DispatchSourceFileSystemObject?
    private var imageEditFileDescriptor: Int32 = -1
    private var imageEditEntryId: UUID?

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
        stopWatchingImageFile()
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
        helpLabel.attributedStringValue = makeHelpString()
        helpButton.title = "[?]"
        helpButton.font = retroFontSmall
        quitButton.title = L.quit
        quitButton.font = retroFontSmall
        permissionWarningButton.toolTip = L.permissionWarningTooltip
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
    }

    private func setupHelpLabel() {
        helpLabel = NSTextField(labelWithString: "")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = retroFontSmall
        helpLabel.textColor = retroDimGreen.withAlphaComponent(0.6)
        helpLabel.backgroundColor = .clear
        helpLabel.isEditable = false
        helpLabel.isBezeled = false
        helpLabel.alignment = .left
        helpLabel.attributedStringValue = makeHelpString()

        helpButton = NSButton(title: "[?]", target: self, action: #selector(helpButtonClicked))
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.isBordered = false
        helpButton.font = retroFontSmall
        helpButton.contentTintColor = retroDimGreen.withAlphaComponent(0.5)

        quitButton = NSButton(title: L.quit, target: self, action: #selector(quitClicked))
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        quitButton.isBordered = false
        quitButton.font = retroFontSmall
        quitButton.contentTintColor = retroDimGreen.withAlphaComponent(0.5)

        permissionWarningButton = NSButton(title: "⚠", target: self, action: #selector(permissionWarningClicked))
        permissionWarningButton.translatesAutoresizingMaskIntoConstraints = false
        permissionWarningButton.isBordered = false
        permissionWarningButton.font = retroFontSmall
        permissionWarningButton.contentTintColor = NSColor.orange
        permissionWarningButton.toolTip = L.permissionWarningTooltip
        permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
        permissionWarningButton.isHidden = true

        containerView.addSubview(helpLabel)
        containerView.addSubview(permissionWarningButton)
        containerView.addSubview(helpButton)
        containerView.addSubview(quitButton)

        NSLayoutConstraint.activate([
            helpLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -7),
            helpLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            helpLabel.heightAnchor.constraint(equalToConstant: 18),

            permissionWarningButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            permissionWarningButton.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -6),
            permissionWarningButton.heightAnchor.constraint(equalToConstant: 20),

            helpButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            helpButton.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -8),
            helpButton.heightAnchor.constraint(equalToConstant: 20),

            quitButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            quitButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            quitButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    @objc private func helpButtonClicked() {
        toggleHelp()
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

        let helpContent = NSTextField(labelWithString: "")
        helpContent.translatesAutoresizingMaskIntoConstraints = false
        helpContent.backgroundColor = .clear
        helpContent.isBezeled = false
        helpContent.isEditable = false
        helpContent.maximumNumberOfLines = 0
        helpContent.lineBreakMode = .byWordWrapping
        helpContent.alignment = .center
        helpContent.attributedStringValue = makeHelpContent()

        let dismissLabel = NSTextField(labelWithString: "")
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        dismissLabel.backgroundColor = .clear
        dismissLabel.isBezeled = false
        dismissLabel.isEditable = false
        dismissLabel.alignment = .center
        dismissLabel.attributedStringValue = makeDismissString()

        overlay.addSubview(helpContent)
        overlay.addSubview(dismissLabel)

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
            let linkAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: retroGreen.withAlphaComponent(0.8),
                .font: dimFont,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            let attrStr = NSMutableAttributedString()
            attrStr.append(NSAttributedString(string: L.helpAccessibility + " ", attributes: hintAttrs))
            attrStr.append(NSAttributedString(string: L.helpAccessibilityLink, attributes: linkAttrs))
            attrStr.append(NSAttributedString(string: ",\n" + L.helpAccessibilitySteps, attributes: hintAttrs))
            accessibilityButton.attributedTitle = attrStr
            overlay.addSubview(accessibilityButton)

            NSLayoutConstraint.activate([
                accessibilityButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                accessibilityButton.topAnchor.constraint(equalTo: helpContent.bottomAnchor, constant: 24),
                accessibilityButton.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 60),
                accessibilityButton.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -60),
            ])
        }

        // Insert below effectsView so CRT effects still show on top
        let effectsIndex = containerView.subviews.firstIndex(of: effectsView) ?? containerView.subviews.count
        containerView.addSubview(overlay, positioned: .below, relativeTo: effectsView)
        _ = effectsIndex // suppress warning

        NSLayoutConstraint.activate([
            helpContent.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            helpContent.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -40),
            helpContent.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 60),
            helpContent.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -60),

            dismissLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dismissLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24),
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(helpOverlayClicked))
        clickGesture.delegate = self
        overlay.addGestureRecognizer(clickGesture)

        helpOverlay = overlay
    }

    private func dismissHelp() {
        helpOverlay?.removeFromSuperview()
        helpOverlay = nil
    }

    @objc private func helpOverlayClicked() {
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

    private func makeDismissString() -> NSAttributedString {
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
        return NSAttributedString(string: L.helpDismiss, attributes: attrs)
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
        permissionWarningButton?.isHidden = AXIsProcessTrusted() || !hasItems
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

    private func makeHelpString(for entry: ClipboardEntry? = nil) -> NSAttributedString {
        let str = NSMutableAttributedString()
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        str.append(NSAttributedString(string: "1-9 ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.pasteNth + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Enter ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.paste + "  ", attributes: dimAttrs))

        // Dynamic shift hint based on selected entry's format category
        if let entry = entry, entry.entryType == .text {
            switch entry.formatCategory {
            case .richText:
                str.append(NSAttributedString(string: "⇧ ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.plain + "  ", attributes: dimAttrs))
            case .plainMarkdown:
                str.append(NSAttributedString(string: "⇧ ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.rich + "  ", attributes: dimAttrs))
            case .richMarkdown:
                str.append(NSAttributedString(string: "⇧ ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.markdownFormat + "  ", attributes: dimAttrs))
            case .plainText:
                break // No shift hint for plain text
            }
        }

        str.append(NSAttributedString(string: "^N/^P ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.select + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Tab ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.expand + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "^E ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.edit + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "⌘S ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.star + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "⌘D ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.delete + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.close, attributes: dimAttrs))
        return str
    }

    private func updateHelpLabel() {
        let entry = filteredEntries.indices.contains(selectedIndex) ? filteredEntries[selectedIndex] : nil
        helpLabel.attributedStringValue = makeHelpString(for: entry)
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
        indicator.font = retroFont
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
                indicator.widthAnchor.constraint(equalToConstant: 16),

                scrollContainer.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                scrollContainer.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                scrollContainer.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
                scrollContainer.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),

                timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                timeLabel.widthAnchor.constraint(equalToConstant: 70),

                deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                deleteButton.widthAnchor.constraint(equalToConstant: 24),
                deleteButton.heightAnchor.constraint(equalToConstant: 24)
            ])

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
                        indicator.widthAnchor.constraint(equalToConstant: 16),

                        iv.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                        iv.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                        iv.widthAnchor.constraint(equalToConstant: imgW),
                        iv.heightAnchor.constraint(equalToConstant: imgH),

                        contentLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                        contentLabel.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 4),
                        contentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),

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
                        indicator.widthAnchor.constraint(equalToConstant: 16),

                        iv.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                        iv.topAnchor.constraint(equalTo: cell.topAnchor, constant: 7),
                        iv.widthAnchor.constraint(equalToConstant: thumbSize),
                        iv.heightAnchor.constraint(equalToConstant: thumbSize),

                        contentLabel.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 8),
                        contentLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                        contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -8),
                        contentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),

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
                    indicator.widthAnchor.constraint(equalToConstant: 16),

                    contentLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
                    contentLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                    contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -8),
                    contentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),

                    timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
                    timeLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                    timeLabel.widthAnchor.constraint(equalToConstant: 70),

                    deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                    deleteButton.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
                    deleteButton.widthAnchor.constraint(equalToConstant: 24),
                    deleteButton.heightAnchor.constraint(equalToConstant: 24)
                ])
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
        let oldRow = hoveredRow
        hoveredRow = nil
        mouseInIndicatorZone = false
        if let old = oldRow {
            tableView.reloadData(forRowIndexes: IndexSet(integer: old), columnIndexes: IndexSet(integer: 0))
        }
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

    private func selectCurrentAsPlainText(at index: Int? = nil) {
        let idx = index ?? selectedIndex
        guard idx < filteredEntries.count else { return }
        historyDelegate?.didSelectEntryAsPlainText(filteredEntries[idx])
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

    private func enterEditMode() {
        guard selectedIndex < filteredEntries.count else { return }
        let entry = filteredEntries[selectedIndex]
        guard !entry.isPassword else { return }

        switch entry.entryType {
        case .text:
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
            quitButton.isHidden = true
            permissionWarningButton.isHidden = true
            emptyStateView?.isHidden = true

            monacoEditorView = editorView

            let language = MonacoEditorView.detectLanguage(entry.content)
            editorView.setContent(entry.content, language: language)

            // Ensure WKWebView gets keyboard focus after layout pass
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                editorView.focusEditor()
            }
        case .image:
            openImageInEditor(entry)
        case .fileURL:
            openFileInEditor(entry)
        }
    }

    private func openImageInEditor(_ entry: ClipboardEntry) {
        guard let data = entry.imageData else { return }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("freeboard")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let ext = imageExtension(for: data)
        let tempFile = tempDir.appendingPathComponent("clipboard-\(entry.id.uuidString).\(ext)")
        do {
            try data.write(to: tempFile)
            NSWorkspace.shared.open(tempFile)
            watchImageFile(at: tempFile, entryId: entry.id)
        } catch {
            NSSound.beep()
        }
    }

    private func watchImageFile(at url: URL, entryId: UUID) {
        // Clean up any existing watcher
        stopWatchingImageFile()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        imageEditFileDescriptor = fd
        imageEditEntryId = entryId

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self = self, let eid = self.imageEditEntryId else { return }
            // Small delay: Preview may write in stages
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                guard let newData = try? Data(contentsOf: url), !newData.isEmpty else { return }
                self.clipboardManager?.updateEntryImageData(id: eid, newData: newData)
            }
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        source.resume()
        imageEditSource = source
    }

    private func stopWatchingImageFile() {
        imageEditSource?.cancel()
        imageEditSource = nil
        imageEditFileDescriptor = -1
        imageEditEntryId = nil
    }

    private func openFileInEditor(_ entry: ClipboardEntry) {
        guard let url = entry.fileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSSound.beep()
        }
    }

    private func imageExtension(for data: Data) -> String {
        guard data.count >= 4 else { return "tiff" }
        let header = [UInt8](data.prefix(4))
        if header[0] == 0x89 && header[1] == 0x50 { return "png" }
        if header[0] == 0xFF && header[1] == 0xD8 { return "jpg" }
        return "tiff"
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
            quitButton.isHidden = false
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
        if event.keyCode == 36 { // Enter
            if editingIndex != nil { return } // Let text view handle it
            if event.modifierFlags.contains(.shift) {
                selectCurrentAsPlainText()
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
                    selectCurrentAsPlainText(at: index)
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
            handleEnter(); return true
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
