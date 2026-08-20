import Foundation

/// An absolute filesystem path normalised into its components, so containment
/// can be decided component-wise instead of by string prefix.
///
/// String prefix matching is the obvious implementation and it is wrong in a way
/// that matters here: `"/Users/r/Devious".hasPrefix("/Users/r/Dev")` is `true`,
/// so a naive auditor would report a grant on `~/Dev` as covering a sibling
/// directory it cannot actually reach.
public struct PathScope: Hashable, Sendable, CustomStringConvertible {

    /// Normalised, non-empty path components. Never contains `""`, `"."` or `".."`.
    public let components: [String]

    /// Parses an absolute POSIX path.
    ///
    /// Returns `nil` for relative paths and for paths whose `..` segments escape
    /// the root. Both are rejected rather than repaired: a security policy that
    /// silently reinterprets an input it did not understand is worse than one
    /// that refuses it.
    public init?(_ path: String) {
        guard path.hasPrefix("/") else { return nil }
        var stack: [String] = []
        for raw in path.split(separator: "/", omittingEmptySubsequences: true) {
            let part = String(raw)
            if part == "." { continue }
            if part == ".." {
                if stack.isEmpty { return nil }
                stack.removeLast()
                continue
            }
            stack.append(part)
        }
        self.components = stack
    }

    private init(components: [String]) {
        self.components = components
    }

    /// The filesystem root, which contains every other scope.
    public static let root = PathScope(components: [])

    /// The enclosing directory, or `nil` at the root.
    public var parent: PathScope? {
        guard !components.isEmpty else { return nil }
        return PathScope(components: Array(components.dropLast()))
    }

    /// `true` when `other` is this scope or lies beneath it.
    public func contains(_ other: PathScope) -> Bool {
        guard components.count <= other.components.count else { return false }
        for index in components.indices where components[index] != other.components[index] {
            return false
        }
        return true
    }

    /// How many directory levels `other` sits below this scope, or `nil` if it is not contained.
    public func depth(of other: PathScope) -> Int? {
        guard contains(other) else { return nil }
        return other.components.count - components.count
    }

    public var description: String { "/" + components.joined(separator: "/") }
}
