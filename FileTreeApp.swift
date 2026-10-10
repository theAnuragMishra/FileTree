import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let viewModel = TreeViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()

        let contentView = ContentView(viewModel: viewModel)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 500, height: 400)
        win.center()
        win.title = "FileTree"
        win.contentView = NSHostingView(rootView: contentView)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(nil)

        self.window = win

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About FileTree", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide FileTree", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit FileTree", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

final class FileItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool

    @Published var isExpanded: Bool = false
    @Published var children: [FileItem]? = nil

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
    }

    func toggleExpansion() {
        guard isDirectory else { return }
        if isExpanded {
            isExpanded = false
        } else {
            if children == nil {
                loadChildren()
            }
            isExpanded = true
        }
    }

    func loadChildren() {
        do {
            let fileManager = FileManager.default
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            self.children = urls
                .map { itemUrl in
                    let isDir = (try? itemUrl.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    return FileItem(url: itemUrl, isDirectory: isDir)
                }
                .sorted { a, b in
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory && !b.isDirectory
                    }
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
        } catch {
            self.children = []
        }
    }
}

final class TreeViewModel: ObservableObject {
    @Published var pathInput: String = ""
    @Published var rootItems: [FileItem] = []
    @Published var statusMessage: String? = nil

    init() {
        let args = CommandLine.arguments.dropFirst()
        for arg in args {
            if !arg.hasPrefix("-") {
                loadDirectory(arg)
                break
            }
        }
    }

    func loadDirectory(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rootItems = []
            statusMessage = "Please enter a root directory path."
            return
        }

        var expandedPath = NSString(string: trimmed).expandingTildeInPath
        if !expandedPath.hasPrefix("/") {
            let cwd = FileManager.default.currentDirectoryPath
            expandedPath = (cwd as NSString).appendingPathComponent(expandedPath)
        }

        let standardizedUrl = URL(fileURLWithPath: expandedPath).standardized
        let resolvedPath = standardizedUrl.path
        self.pathInput = resolvedPath

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDir) else {
            rootItems = []
            statusMessage = "Directory not found: \(trimmed)"
            return
        }

        guard isDir.boolValue else {
            rootItems = []
            statusMessage = "Specified path is a file, not a directory: \(trimmed)"
            return
        }

        let rootNode = FileItem(url: standardizedUrl, isDirectory: true)
        rootNode.loadChildren()

        if let children = rootNode.children {
            self.rootItems = children
            self.statusMessage = children.isEmpty ? "Directory is empty" : nil
        } else {
            self.rootItems = []
            self.statusMessage = "Unable to read directory contents"
        }
    }

    func loadRootDirectory() {
        loadDirectory(pathInput)
    }
}

struct FileRowView: View {
    @ObservedObject var item: FileItem
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if level > 0 {
                    Spacer().frame(width: CGFloat(level * 20))
                }

                if item.isDirectory {
                    Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    Image(systemName: item.isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.accentColor)

                    Text(item.name)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                } else {
                    Spacer().frame(width: 14)

                    Image(systemName: "doc")
                        .foregroundColor(.secondary)

                    Text(item.name)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .onTapGesture {
                if item.isDirectory {
                    item.toggleExpansion()
                }
            }

            if item.isDirectory && item.isExpanded {
                if let children = item.children {
                    if children.isEmpty {
                        HStack {
                            Spacer().frame(width: CGFloat((level + 1) * 20 + 14))
                            Text("(empty folder)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    } else {
                        ForEach(children) { child in
                            FileRowView(item: child, level: level + 1)
                        }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: TreeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Root Directory Input Bar
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)

                TextField("Enter root directory path (e.g. ~ or /Users/john)", text: $viewModel.pathInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.loadRootDirectory()
                    }

                Button("Open") {
                    viewModel.loadRootDirectory()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.top, .horizontal])

            Divider()

            // Tree View
            if let message = viewModel.statusMessage, viewModel.rootItems.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(message)
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    Spacer()
                }
            } else if viewModel.rootItems.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Enter a directory path above to view its contents")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(viewModel.rootItems) { item in
                            FileRowView(item: item, level: 0)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

@main
struct FileTreeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
