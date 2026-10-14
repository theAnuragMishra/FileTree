import AppKit
import Darwin
import FileTreeCore
import MachO

@main
@MainActor
enum Launcher {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.count == 1, arguments[0] == "--help" || arguments[0] == "-h" {
            print("Usage: ft <directory>")
            return
        }

        guard arguments.count == 1 else {
            writeStandardError("Usage: ft <directory>")
            exit(64)
        }

        do {
            let directoryURL = try DirectoryReader.directoryURL(for: arguments[0])
            let bundleURL = try applicationBundleURL()
            try await open(directoryURL, withApplicationAt: bundleURL)
        } catch {
            writeStandardError("ft: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        }
    }

    private static func open(_ directoryURL: URL, withApplicationAt bundleURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false

        // The callback runs on a concurrent queue; only Void crosses back to the main actor.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.open(
                [directoryURL],
                withApplicationAt: bundleURL,
                configuration: configuration
            ) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if application != nil {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: LauncherError(message: "FileTree did not launch"))
                }
            }
        }
    }

    private static func applicationBundleURL() throws -> URL {
        let executableURL = try resolvedExecutableURL()
        let macOSURL = executableURL.deletingLastPathComponent()
        let contentsURL = macOSURL.deletingLastPathComponent()
        let bundleURL = contentsURL.deletingLastPathComponent()

        guard executableURL.lastPathComponent == "ft",
              macOSURL.lastPathComponent == "MacOS",
              contentsURL.lastPathComponent == "Contents",
              bundleURL.pathExtension.lowercased() == "app" else {
            throw LauncherError(
                message: "ft must be inside FileTree.app/Contents/MacOS/ft; use a PATH symlink, not a copy"
            )
        }

        guard let bundle = Bundle(url: bundleURL),
              bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "FileTree" else {
            throw LauncherError(message: "invalid FileTree app bundle: \(bundleURL.path)")
        }

        let mainExecutableURL = macOSURL.appendingPathComponent("FileTree", isDirectory: false)
        let attributes = try? mainExecutableURL.resourceValues(forKeys: [.isRegularFileKey])
        guard attributes?.isRegularFile == true,
              FileManager.default.isExecutableFile(atPath: mainExecutableURL.path) else {
            throw LauncherError(
                message: "missing or non-executable FileTree app binary: \(mainExecutableURL.path)"
            )
        }

        return bundleURL
    }

    private static func resolvedExecutableURL() throws -> URL {
        var bufferSize: UInt32 = 0
        guard _NSGetExecutablePath(nil, &bufferSize) == -1, bufferSize > 0 else {
            throw LauncherError(message: "cannot determine the ft executable path")
        }

        var buffer = [CChar](repeating: 0, count: Int(bufferSize))
        let executableURL = buffer.withUnsafeMutableBufferPointer { buffer -> URL? in
            guard let address = buffer.baseAddress,
                  _NSGetExecutablePath(address, &bufferSize) == 0 else {
                return nil
            }

            return URL(
                fileURLWithFileSystemRepresentation: address,
                isDirectory: false,
                relativeTo: nil
            ).resolvingSymlinksInPath()
        }

        guard let executableURL else {
            throw LauncherError(message: "cannot resolve the ft executable path")
        }
        return executableURL
    }

    private static func writeStandardError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct LauncherError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
