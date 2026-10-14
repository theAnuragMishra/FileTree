import Foundation

public final class DirectoryNode {
    public let entry: DirectoryEntry
    public private(set) var children: [DirectoryNode]?

    public init(entry: DirectoryEntry) {
        self.entry = entry
    }

    @discardableResult
    public func loadChildren() throws -> [DirectoryNode] {
        if let children { return children }
        let loaded = entry.isDirectory
            ? try DirectoryReader.contents(of: entry.url).map(DirectoryNode.init)
            : []
        children = loaded
        return loaded
    }
}
