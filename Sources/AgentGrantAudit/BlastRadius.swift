import Foundation

/// What a set of folder grants actually reaches, measured against real paths.
///
/// The dialog asks about a folder. The consequence is a project count, and the
/// two numbers are usually nothing like each other — which is exactly why the
/// dialog is easy to click through.
public struct BlastRadius: Equatable, Sendable {
    public let reachableProjects: [PathScope]
    public let widestGrant: PermittedFolder?

    public var projectCount: Int { reachableProjects.count }

    /// - Parameters:
    ///   - folders: live and expired grants; expired ones contribute nothing.
    ///   - projects: absolute paths to projects discovered on disk.
    ///   - now: the instant expiry is evaluated against.
    public static func measure(folders: [PermittedFolder], projects: [PathScope], now: Date) -> BlastRadius {
        var reachable: [PathScope] = []
        for project in projects where folders.contains(where: { $0.covers(project, at: now) }) {
            reachable.append(project)
        }
        reachable.sort { $0.description < $1.description }

        let widest = folders
            .filter { !$0.expiry.hasExpired(at: now) }
            .map { folder -> (PermittedFolder, Int) in
                (folder, projects.filter { folder.covers($0, at: now) }.count)
            }
            .max { left, right in
                if left.1 != right.1 { return left.1 < right.1 }
                // Tie-break on the shallower grant, which is the more alarming one.
                return left.0.subtreeRoot.components.count > right.0.subtreeRoot.components.count
            }?
            .0

        return BlastRadius(reachableProjects: reachable, widestGrant: widest)
    }
}
