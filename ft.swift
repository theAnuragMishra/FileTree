import Foundation
import AppKit

func resolveExecutableURL(for path: String) -> URL {
    let url = URL(fileURLWithPath: path)
    return url.resolvingSymlinksInPath()
}

func findEnclosingAppBundle(for url: URL) -> URL? {
    var current = url
    while current.path != "/" && current.pathComponents.count > 1 {
        if current.pathExtension == "app" {
            return current
        }
        current = current.deletingLastPathComponent()
    }
    return nil
}

func findAppBundle(relativeTo exeURL: URL) -> URL? {
    // 1. If ft is inside FileTree.app (e.g. /Applications/FileTree.app/Contents/MacOS/ft)
    if let bundle = findEnclosingAppBundle(for: exeURL) {
        return bundle
    }

    // 2. Check build directories or standard Applications folder
    let exeDir = exeURL.deletingLastPathComponent()
    let candidates = [
        exeDir.appendingPathComponent("FileTree.app"),
        exeDir.appendingPathComponent("build/FileTree.app"),
        exeDir.deletingLastPathComponent().appendingPathComponent("build/FileTree.app"),
        URL(fileURLWithPath: "/Applications/FileTree.app")
    ]

    for candidate in candidates {
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    return nil
}

func main() {
    let rawPath = CommandLine.arguments.dropFirst().first ?? "."
    let expandedPath = NSString(string: rawPath).expandingTildeInPath
    let fullURL = URL(fileURLWithPath: expandedPath).standardized

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: fullURL.path, isDirectory: &isDir) else {
        fputs("ft: No such file or directory: \(rawPath)\n", stderr)
        exit(1)
    }

    let realExeURL = resolveExecutableURL(for: CommandLine.arguments[0])
    guard let appURL = findAppBundle(relativeTo: realExeURL) else {
        fputs("ft: Could not find FileTree.app. Please run build.sh first.\n", stderr)
        exit(1)
    }

    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    config.arguments = [fullURL.path]
    config.createsNewApplicationInstance = true

    let sem = DispatchSemaphore(value: 0)
    var launchError: Error?
    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
        launchError = error
        sem.signal()
    }
    _ = sem.wait(timeout: .now() + 5)

    if let launchError = launchError {
        fputs("ft: Failed to launch FileTree: \(launchError.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
