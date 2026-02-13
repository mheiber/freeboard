import Cocoa

protocol ClipboardHistoryDelegate: AnyObject {
    func didSelectEntry(_ entry: ClipboardEntry)
    func didDeleteEntry(_ entry: ClipboardEntry)
    func didDismiss()
}

class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    weak var historyDelegate: ClipboardHistoryDelegate?
    var clipboardManager: ClipboardManager?

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var searchField: NSTextField!
    private var helpLabel: NSTextField!
    private var quitButton: NSButton!
    private var containerView: NSView!
    private var effectsView: RetroEffectsView!

    private var filteredEntries: [ClipboardEntry] = []
    private var selectedIndex: Int = 0
    private var searchQuery: String = ""

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
        setupTableView()
        setupHelpLabel()

        effectsView = RetroEffectsView(frame: frame)
        effectsView.autoresizingMask = [.width, .height]
        mainView.addSubview(effectsView)

        self.view = mainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadEntries()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        searchField.stringValue = ""
        searchQuery = ""
        selectedIndex = 0
        refreshLocalization()
        reloadEntries()
        view.window?.makeFirstResponder(searchField)
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
        tableView.doubleAction = #selector(tableDoubleClicked)

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
        str.append(NSAttributedString(string: "^N/^P ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.navigate + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Enter ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.paste + "  ", attributes: dimAttrs))
        str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
        str.append(NSAttributedString(string: L.close, attributes: dimAttrs))
        return str
    }

    // MARK: - Data

    func reloadEntries() {
        guard let manager = clipboardManager else { return }
        if searchQuery.isEmpty {
            filteredEntries = manager.entries
        } else {
            filteredEntries = FuzzySearch.filter(entries: manager.entries, query: searchQuery)
        }
        selectedIndex = min(selectedIndex, max(filteredEntries.count - 1, 0))
        tableView?.reloadData()
        if !filteredEntries.isEmpty {
            tableView?.scrollRowToVisible(selectedIndex)
        }
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

        let cell = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 50))
        cell.wantsLayer = true
        cell.layer?.backgroundColor = isSelected ? retroSelectionBg.cgColor : NSColor.clear.cgColor

        let indicator = NSTextField(labelWithString: isSelected ? ">" : " ")
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.font = retroFont
        indicator.textColor = retroGreen
        indicator.backgroundColor = .clear
        indicator.isBezeled = false
        cell.addSubview(indicator)

        let contentLabel = NSTextField(labelWithString: "")
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.font = retroFont
        contentLabel.textColor = isSelected ? retroGreen : retroDimGreen
        contentLabel.backgroundColor = .clear
        contentLabel.isBezeled = false
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.maximumNumberOfLines = 1

        let displayText = entry.displayContent
            .replacingOccurrences(of: "\n", with: "↵ ")
            .replacingOccurrences(of: "\t", with: "→ ")
        contentLabel.stringValue = displayText
        cell.addSubview(contentLabel)

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

        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            indicator.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 16),

            contentLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6),
            contentLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),

            timeLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            timeLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            timeLabel.widthAnchor.constraint(equalToConstant: 70),

            deleteButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        50
    }

    // MARK: - Actions

    @objc private func deleteClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredEntries.count else { return }
        historyDelegate?.didDeleteEntry(filteredEntries[row])
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredEntries.count else { return }
        selectCurrent(at: row)
    }

    private func selectCurrent(at index: Int? = nil) {
        let idx = index ?? selectedIndex
        guard idx < filteredEntries.count else { return }
        historyDelegate?.didSelectEntry(filteredEntries[idx])
    }

    // MARK: - Keyboard handling

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 { historyDelegate?.didDismiss(); return }
        if event.keyCode == 36 { selectCurrent(); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "n" { moveSelection(by: 1); return }
        if flags.contains(.control) && event.charactersIgnoringModifiers == "p" { moveSelection(by: -1); return }
        if event.keyCode == 125 { moveSelection(by: 1); return }
        if event.keyCode == 126 { moveSelection(by: -1); return }

        super.keyDown(with: event)
    }

    private func moveSelection(by delta: Int) {
        guard !filteredEntries.isEmpty else { return }
        selectedIndex = max(0, min(filteredEntries.count - 1, selectedIndex + delta))
        tableView.reloadData()
        tableView.scrollRowToVisible(selectedIndex)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        searchQuery = searchField.stringValue
        selectedIndex = 0
        reloadEntries()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) { selectCurrent(); return true }
        if commandSelector == #selector(cancelOperation(_:)) { historyDelegate?.didDismiss(); return true }
        if commandSelector == #selector(moveDown(_:)) { moveSelection(by: 1); return true }
        if commandSelector == #selector(moveUp(_:)) { moveSelection(by: -1); return true }
        return false
    }
}
