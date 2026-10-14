import Foundation

public enum DirectoryError: LocalizedError {
    case emptyPath
    case doesNotExist(String)
    case notADirectory(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "Enter a directory path."
        case .doesNotExist(let path):
            return "The path does not exist: \(path)"
        case .notADirectory(let path):
            return "The path is not a directory: \(path)"
        }
    }
}

public struct DirectoryEntry: Equatable, Sendable {
    public let url: URL
    public let isDirectory: Bool

    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }
}

public enum DirectoryReader {
    public static func directoryURL(for path: String, relativeTo baseURL: URL? = nil) throws -> URL {
        guard !path.isEmpty else { throw DirectoryError.emptyPath }

        let expandedPath = (path as NSString).expandingTildeInPath
        let base = baseURL ?? URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let url = URL(fileURLWithPath: expandedPath, isDirectory: true, relativeTo: base)
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw DirectoryError.doesNotExist(url.path)
        }
        guard isDirectory.boolValue else { throw DirectoryError.notADirectory(url.path) }
        return url
    }

    public static func contents(of directoryURL: URL) throws -> [DirectoryEntry] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            var isDirectory = values?.isDirectory ?? false
            if values == nil || values?.isSymbolicLink == true {
                var targetIsDirectory: ObjCBool = false
                _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &targetIsDirectory)
                isDirectory = targetIsDirectory.boolValue
            }
            return DirectoryEntry(url: url, isDirectory: isDirectory)
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? lhs.name < rhs.name : order == .orderedAscending
        }
    }
}
