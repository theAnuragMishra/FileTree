import AppKit
import FileTreeCore

@MainActor
final class FileTreeWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let pathField = NSTextField()
    private let outlineView = NSOutlineView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Enter a directory path above.")
    private var root: DirectoryNode?
    private var failedNode: DirectoryNode?
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("FileTreeCell")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FileTree"
        window.minSize = NSSize(width: 380, height: 260)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        super.init(window: window)
        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError("FileTree does not use storyboards.")
    }

    func bringToFront() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.unhide(nil)
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func openDirectory(atPath path: String) {
        pathField.stringValue = path
        failedNode = nil
        do {
            let url = try DirectoryReader.directoryURL(for: path)
            let newRoot = DirectoryNode(entry: DirectoryEntry(url: url, isDirectory: true))
            let children = try newRoot.loadChildren()
            root = newRoot
            pathField.stringValue = url.path
            outlineView.reloadData()
            outlineView.deselectAll(nil)
            showStatus(children.isEmpty ? "This directory is empty." : nil)
        } catch {
            root = nil
            outlineView.reloadData()
            showStatus(error.localizedDescription, isError: true)
        }
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }
        pathField.placeholderString = "/path/to/directory"
        pathField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        pathField.cell?.isScrollable = true
        pathField.target = self
        pathField.action = #selector(openEnteredDirectory(_:))
        pathField.setAccessibilityLabel("Root directory")
        pathField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let openButton = NSButton(title: "Open", target: self, action: #selector(openEnteredDirectory(_:)))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"
        openButton.setContentHuggingPriority(.required, for: .horizontal)
        let inputRow = NSStackView(views: [pathField, openButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        inputRow.setContentHuggingPriority(.required, for: .vertical)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Name"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = 24
        outlineView.indentationPerLevel = 18
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(toggleClickedDirectory(_:))
        outlineView.setAccessibilityLabel("Directory tree")

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = outlineView
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.setContentHuggingPriority(.required, for: .vertical)

        let stack = NSStackView(views: [inputRow, scrollView, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            inputRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
        window?.makeFirstResponder(pathField)
    }

    private func showStatus(_ message: String?, isError: Bool = false) {
        statusLabel.stringValue = message ?? ""
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel.isHidden = message == nil
    }

    @objc private func openEnteredDirectory(_ sender: Any?) {
        openDirectory(atPath: pathField.stringValue)
    }

    @objc private func toggleClickedDirectory(_ sender: NSOutlineView) {
        guard let event = NSApp.currentEvent,
              event.type == .leftMouseDown || event.type == .leftMouseUp,
              event.clickCount == 1,
              sender.clickedRow >= 0,
              let node = sender.item(atRow: sender.clickedRow) as? DirectoryNode,
              node.entry.isDirectory else { return }

        let point = sender.convert(event.locationInWindow, from: nil)
        // AppKit already handles clicks on its disclosure triangle.
        guard !sender.frameOfOutlineCell(atRow: sender.clickedRow).contains(point) else { return }
        if sender.isItemExpanded(node) {
            sender.collapseItem(node)
        } else {
            sender.expandItem(node)
        }
    }

    private func children(of item: Any?) -> [DirectoryNode] {
        guard let node = item as? DirectoryNode else { return root?.children ?? [] }
        do {
            let children = try node.loadChildren()
            if failedNode === node {
                failedNode = nil
                showStatus(nil)
            }
            return children
        } catch {
            failedNode = node
            showStatus("Could not read \(node.entry.url.path): \(error.localizedDescription)", isError: true)
            return []
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? DirectoryNode)?.entry.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? DirectoryNode else { return nil }
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: Self.cellIdentifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = Self.cellIdentifier
            let icon = NSImageView()
            let label = NSTextField(labelWithString: "")
            icon.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleProportionallyDown
            icon.setAccessibilityElement(false)
            label.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(icon)
            cell.addSubview(label)
            cell.imageView = icon
            cell.textField = label
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = node.entry.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: node.entry.url.path)
        return cell
    }
}
