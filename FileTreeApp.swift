import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
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

    func loadRootDirectory() {
        let trimmed = pathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rootItems = []
            statusMessage = "Please enter a root directory path."
            return
        }

        let expandedPath = NSString(string: trimmed).expandingTildeInPath
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDir) else {
            rootItems = []
            statusMessage = "Directory not found: \(trimmed)"
            return
        }

        guard isDir.boolValue else {
            rootItems = []
            statusMessage = "Specified path is a file, not a directory: \(trimmed)"
            return
        }

        let rootUrl = URL(fileURLWithPath: expandedPath)
        let rootNode = FileItem(url: rootUrl, isDirectory: true)
        rootNode.loadChildren()

        if let children = rootNode.children {
            self.rootItems = children
            self.statusMessage = children.isEmpty ? "Directory is empty" : nil
        } else {
            self.rootItems = []
            self.statusMessage = "Unable to read directory contents"
        }
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
        .frame(minWidth: 550, minHeight: 450)
    }
}

@main
struct FileTreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = TreeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .navigationTitle("FileTree")
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
