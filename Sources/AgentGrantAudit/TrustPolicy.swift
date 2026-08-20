import Foundation

/// The reviewable, committable half of agent authorisation.
///
/// The point of writing this down is that a grant clicked through in a dialog
/// leaves no artefact anyone can review. A policy file has a diff, an owner and
/// a history.
public struct TrustPolicy: Equatable, Sendable {

    /// Team identifiers permitted to drive the toolchain. Empty means "trust no agent".
    public let approvedTeamIdentifiers: Set<String>

    /// Roots that folder grants may be scoped to — normally repository roots,
    /// never a developer's home directory.
    public let approvedGrantRoots: [PathScope]

    /// Longest permanent-equivalent lifetime tolerated for a grant.
    public let maximumGrantLifetime: TimeInterval

    /// Whether a grant with no expiry is tolerated at all.
    public let permitsNonExpiringGrants: Bool

    public init(
        approvedTeamIdentifiers: Set<String>,
        approvedGrantRoots: [PathScope],
        maximumGrantLifetime: TimeInterval = 24 * 60 * 60,
        permitsNonExpiringGrants: Bool = false
    ) {
        self.approvedTeamIdentifiers = approvedTeamIdentifiers
        self.approvedGrantRoots = approvedGrantRoots
        self.maximumGrantLifetime = maximumGrantLifetime
        self.permitsNonExpiringGrants = permitsNonExpiringGrants
    }

    /// `true` when some approved root contains `scope`.
    public func approvesRoot(of scope: PathScope) -> Bool {
        approvedGrantRoots.contains { $0.contains(scope) }
    }
}
