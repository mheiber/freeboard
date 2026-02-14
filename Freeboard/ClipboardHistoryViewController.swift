import Cocoa

protocol ClipboardHistoryDelegate: AnyObject {
    func didSelectEntry(_ entry: ClipboardEntry)
    func didDeleteEntry(_ entry: ClipboardEntry)
    func didDismiss()
}

class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate {

    weak var historyDelegate: ClipboardHistoryDelegate?
    var clipboardManager: ClipboardManager?

    var hasAccessibility = false {
        didSet { updateAccessibilityBanner() }
    }

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var searchField: NSTextField!
    private var helpLabel: NSTextField!
    private var quitButton: NSButton!
    private var containerView: NSView!
    private var effectsView: RetroEffectsView!
    private var accessibilityBanner: NSButton!
    private var scrollViewTopConstraint: NSLayoutConstraint!
    private var emptyStateView: NSView!

    private var filteredEntries: [ClipboardEntry] = []
    private var selectedIndex: Int = 0
    private var expandedIndex: Int? = nil
    private var editingIndex: Int? = nil
    private var editTextView: NSTextView? = nil
    private var searchQuery: String = ""
    private var hoveredRow: Int? = nil
    private var mouseInIndicatorZone: Bool = false

    private let retroGreen = NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)
    private let retroDimGreen = NSColor(red: 0.0, green: 0.6, blue: 0.15, alpha: 1.0)
    private let retroBg = NSColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 0.88)
    private let retroSelectionBg = NSColor(red: 0.0, green: 0.2, blue: 0.05, alpha: 0.9)
    private var retroFont: NSFont {
        if L.current == .zh {
            return NSFont.systemFont(ofSize: 20, weight: .regular)
        }
        return NSFont(name: "Menlo", size: 16) ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    private var retroFontSmall: NSFont {
        if L.current == .zh {
            return NSFont.systemFont(ofSize: 15, weight: .regular)
        }
        return NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    override func loadView() {
        let frame = NSRect(x: 0, y: 0, width: 900, height: 750)
        let mainView = NSView(frame: frame)
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = retroBg.cgColor
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
        setupAccessibilityBanner()
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
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()
        searchField.stringValue = ""
        searchQuery = ""
        selectedIndex = 0
        refreshLocalization()
        reloadEntries()
        updateAccessibilityBanner()
        view.window?.makeFirstResponder(self)
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
        quitButton.title = L.quit
        quitButton.font = retroFontSmall
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
        searchField.focusRingType = .none
        searchField.delegate = self

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

    private func setupAccessibilityBanner() {
        accessibilityBanner = NSButton(frame: .zero)
        accessibilityBanner.translatesAutoresizingMaskIntoConstraints = false
        accessibilityBanner.isBordered = false
        accessibilityBanner.wantsLayer = true
        accessibilityBanner.layer?.backgroundColor = NSColor(red: 0.3, green: 0.15, blue: 0.0, alpha: 0.85).cgColor
        accessibilityBanner.layer?.cornerRadius = 4
        accessibilityBanner.target = self
        accessibilityBanner.action = #selector(accessibilityBannerClicked)

        let warningAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
            .font: retroFontSmall
        ]
        accessibilityBanner.attributedTitle = NSAttributedString(
            string: "\u{26A0} Auto-paste needs Accessibility permission. Click to open Settings.",
            attributes: warningAttrs
        )

        accessibilityBanner.isHidden = true
        containerView.addSubview(accessibilityBanner)
        NSLayoutConstraint.activate([
            accessibilityBanner.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            accessibilityBanner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            accessibilityBanner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            accessibilityBanner.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    @objc private func accessibilityBannerClicked() {
        // Prompt for accessibility permission, then open System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if trusted {
            hasAccessibility = true
            return
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    private func updateAccessibilityBanner() {
        guard accessibilityBanner != nil, scrollViewTopConstraint != nil else { return }
        let showBanner = !hasAccessibility
        accessibilityBanner.isHidden = !showBanner
        scrollViewTopConstraint.constant = showBanner ? 88 : 54
        containerView?.layoutSubtreeIfNeeded()
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
        scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 54)
        NSLayoutConstraint.activate([
            scrollViewTopConstraint,
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

        quitButton = NSButton(title: L.quit, target: self, action: #selector(quitClicked))
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        quitButton.isBordered = false
        quitButton.font = retroFontSmall
        quitButton.contentTintColor = retroDimGreen.withAlphaComponent(0.5)

        containerView.addSubview(helpLabel)
        containerView.addSubview(quitButton)
        NSLayoutConstraint.activate([
            helpLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -7),
            helpLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            helpLabel.heightAnchor.constraint(equalToConstant: 18),

            quitButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            quitButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            quitButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
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

        emptyStateView.addSubview(asciiLabel)
        emptyStateView.addSubview(hintLabel)
        emptyStateView.addSubview(hotkeyLabel)
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
        emptyStateView?.isHidden = !filteredEntries.isEmpty
        scrollView?.isHidden = filteredEntries.isEmpty
    }

    private func makeHelpString() -> NSAttributedString {
        let str = NSMutableAttributedString()
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: retroFontSmall
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.4),
            .font: retroFontSmall
        ]
        str.append(NSAttributedString(string: "1-9 ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.quickSelect + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "^N/^P ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.navigate + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Enter ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.paste + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Tab ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.expand + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "^E ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.edit + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.close, attributes: dimAttrs))
        return str
    }

    // MARK: - Data

    func reloadEntries() {
        guard let manager = clipboardManager else { return }
        if searchQuery.isEmpty {
            let favorites = manager.entries.filter { $0.isFavorite }
            let nonFavorites = manager.entries.filter { !$0.isFavorite }
            filteredEntries = favorites + nonFavorites
        } else {
            filteredEntries = FuzzySearch.filter(entries: manager.entries, query: searchQuery)
        }
        selectedIndex = min(selectedIndex, max(filteredEntries.count - 1, 0))
        tableView?.reloadData()
        if !filteredEntries.isEmpty {
            tableView?.scrollRowToVisible(selectedIndex)
        }
        updateEmptyStateVisibility()
    }

    // MARK: - NSTableViewDataSource

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

        let indicatorTitle: String
        if entry.isFavorite {
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

        let indicator = NSButton(title: indicatorTitle, target: self, action: #selector(favoriteClicked(_:)))
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isBordered = false
        indicator.font = retroFont
        indicator.contentTintColor = retroGreen
        indicator.tag = row
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
            cell.addSubview(nl)
            numberLabel = nl
        } else {
            numberLabel = nil
        }

        let timeLabel = NSTextField(labelWithString: entry.timeAgo)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = retroFontSmall
        timeLabel.textColor = retroDimGreen.withAlphaComponent(0.4)
        timeLabel.backgroundColor = .clear
        timeLabel.isBezeled = false
        timeLabel.alignment = .right
        cell.addSubview(timeLabel)

        let deleteButton = NSButton(title: "×", target: self, action: #selector(deleteClicked(_:)))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isBordered = false
        deleteButton.font = NSFont(name: "Menlo", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        deleteButton.contentTintColor = retroDimGreen.withAlphaComponent(0.5)
        deleteButton.tag = row
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
                    .replacingOccurrences(of: "\n", with: "↵ ")
                    .replacingOccurrences(of: "\t", with: "→ ")
                contentLabel.stringValue = displayText
            }
            cell.addSubview(contentLabel)

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

            if let nl = numberLabel {
                NSLayoutConstraint.activate([
                    nl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                    nl.centerYAnchor.constraint(equalTo: indicator.centerYAnchor),
                ])
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

    @objc private func favoriteClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        clipboardManager?.toggleFavorite(id: filteredEntries[row].id)
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
        if editingIndex != nil { return }
        selectCurrent()
    }

    private func selectCurrent(at index: Int? = nil) {
        let idx = index ?? selectedIndex
        guard idx < filteredEntries.count else { return }
        historyDelegate?.didSelectEntry(filteredEntries[idx])
    }

    private func toggleExpand() {
        guard !filteredEntries.isEmpty else { return }
        if editingIndex != nil { return } // Don't toggle while editing
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
        guard !filteredEntries[selectedIndex].isPassword else { return } // Can't edit passwords
        expandedIndex = selectedIndex
        editingIndex = selectedIndex
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: selectedIndex))
        tableView.reloadData()
        tableView.scrollRowToVisible(selectedIndex)
    }

    private func exitEditMode() {
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

    // MARK: - Keyboard handling

    private var isSearchFieldFocused: Bool {
        view.window?.firstResponder === searchField.currentEditor()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 { // Esc
            if editingIndex != nil {
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
            handleEnter()
            return
        }
        if editingIndex != nil { super.keyDown(with: event); return } // Pass through when editing

        // Normal mode (search field NOT focused): number keys quick select
        if !isSearchFieldFocused {
            if let chars = event.charactersIgnoringModifiers, flags.isEmpty || flags == .shift {
                if let digit = chars.first, digit >= "1" && digit <= "9" {
                    let index = Int(String(digit))! - 1
                    selectCurrent(at: index)
                    return
                }
            }
        }

        if event.keyCode == 48 { toggleExpand(); return } // Tab
        if flags.contains(.control) && event.charactersIgnoringModifiers == "e" { enterEditMode(); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "n" { moveSelection(by: 1); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "p" { moveSelection(by: -1); return }
        if event.keyCode == 125 { moveSelection(by: 1); return }
        if event.keyCode == 126 { moveSelection(by: -1); return }

        // Type-ahead: any printable character focuses the search field and starts a search
        if !isSearchFieldFocused,
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
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
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
