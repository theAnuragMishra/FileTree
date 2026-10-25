import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windowControllers: [FileTreeWindowController] = []
    private var pendingDirectoryURLs: [URL] = []
    private var hasFinishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMenu()

        hasFinishedLaunching = true
        if pendingDirectoryURLs.isEmpty {
            openNewWindow()
        } else {
            for url in pendingDirectoryURLs {
                openNewWindow(for: url)
            }
            pendingDirectoryURLs.removeAll()
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        let directoryURLs = urls.filter(\.isFileURL)
        guard hasFinishedLaunching else {
            pendingDirectoryURLs.append(contentsOf: directoryURLs)
            return
        }
        for url in directoryURLs {
            openNewWindow(for: url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let controller = windowControllers.first(where: { $0.window === sender.mainWindow })
            ?? windowControllers.last {
            controller.bringToFront()
        } else {
            openNewWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowControllers.removeAll { $0.window === window }
    }

    private func openNewWindow(for directoryURL: URL? = nil) {
        let controller = FileTreeWindowController()
        controller.window?.delegate = self
        windowControllers.append(controller)
        controller.bringToFront()
        if let directoryURL {
            controller.openDirectory(atPath: directoryURL.path)
        }
    }

    private func installMenu() {
        let menu = NSMenu()
        let appMenu = addMenu(named: "FileTree", to: menu)
        appMenu.addItem(
            withTitle: "About FileTree",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        let servicesMenu = addMenu(named: "Services", to: appMenu)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide FileTree", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FileTree", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = addMenu(named: "File", to: menu)
        fileMenu.addItem(withTitle: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n").target = self
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let editMenu = addMenu(named: "Edit", to: menu)
        editMenu.addItem(withTitle: "Undo", action: Selector("undo:"), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector("redo:"), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewMenu = addMenu(named: "View", to: menu)
        let fullScreen = viewMenu.addItem(
            withTitle: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreen.keyEquivalentModifierMask = [.command, .control]

        let windowMenu = addMenu(named: "Window", to: menu)
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )

        let helpMenu = addMenu(named: "Help", to: menu)
        helpMenu.addItem(withTitle: "FileTree Help", action: #selector(showFileTreeHelp(_:)), keyEquivalent: "?")
            .target = self

        NSApp.mainMenu = menu
        NSApp.servicesMenu = servicesMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }

    private func addMenu(named title: String, to parent: NSMenu) -> NSMenu {
        let submenu = NSMenu(title: title)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        parent.addItem(item)
        return submenu
    }

    @objc private func newWindow(_ sender: Any?) {
        openNewWindow()
    }

    @objc private func showFileTreeHelp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "FileTree Help"
        alert.informativeText = """
        Enter a directory path and click Open, or press Return.

        Click a folder's name or disclosure triangle to expand or collapse it. Files are displayed, not opened.

        Run ft /path/to/directory in Terminal to open a directory in a new, independent window.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
