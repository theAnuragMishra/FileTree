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
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "FileTree")
        appMenu.addItem(withTitle: "Quit FileTree", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
}
