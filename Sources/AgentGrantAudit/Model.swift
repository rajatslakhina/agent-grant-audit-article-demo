import Foundation

/// How far a folder grant reaches.
public enum GrantScope: String, Sendable {
    /// The grant covers the folder and everything beneath it, to any depth.
    case recursive
    /// The grant covers only projects sitting directly in the folder.
    case directoryOnly
}

/// When a grant stops being honoured.
///
/// Modelled as an enum rather than `Date?` on purpose. `nil` invites the reader
/// to substitute `Date.distantFuture` and carry on comparing, which makes a
/// permanent grant sort like a very long one. It is not a long grant. It is a
/// different kind of object, and the auditor is required to say so out loud.
public enum GrantExpiry: Equatable, Sendable {
    case never
    case at(Date)

    /// `true` only for `.at` instants that have already passed.
    public func hasExpired(at now: Date) -> Bool {
        switch self {
        case .never: return false
        case .at(let instant): return instant <= now
        }
    }

    /// Remaining lifetime in seconds, or `nil` for a permanent grant.
    public func remaining(at now: Date) -> TimeInterval? {
        switch self {
        case .never: return nil
        case .at(let instant): return instant.timeIntervalSince(now)
        }
    }
}

/// An agent Xcode has been told to trust.
///
/// Trust is keyed to the code signature rather than the process name, which is
/// the genuinely good half of the design: `teamIdentifier` is a verifiable,
/// scriptable, provisionable property a build script can assert against.
public struct TrustedAgent: Equatable, Sendable {
    public let signingIdentifier: String
    public let teamIdentifier: String

    public init(signingIdentifier: String, teamIdentifier: String) {
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

/// A folder the user has handed to agents.
public struct FolderGrant: Equatable, Sendable {
    public let scope: PathScope
    public let reach: GrantScope
    public let expiry: GrantExpiry

    public init(scope: PathScope, reach: GrantScope, expiry: GrantExpiry) {
        self.scope = scope
        self.reach = reach
        self.expiry = expiry
    }

    /// `true` when this grant would admit an agent to `project`.
    public func covers(_ project: PathScope, at now: Date) -> Bool {
        guard !expiry.hasExpired(at: now) else { return false }
        switch reach {
        case .recursive:
            return scope.contains(project)
        case .directoryOnly:
            return project.parent == scope
        }
    }
}

/// A decoded snapshot of the local agent-authorisation state.
public struct MCPServerStatus: Equatable, Sendable {
    public let isEnabled: Bool

    /// Whether the machine-wide bypass is active.
    ///
    /// This is the field that makes an empty `grants` array readable at all.
    /// Without it, "no grants" is ambiguous between *nothing is trusted* and
    /// *everything is trusted*, and those are opposite facts.
    public let allowsAllAgents: Bool
    public let trustedAgents: [TrustedAgent]
    public let grants: [FolderGrant]

    public init(isEnabled: Bool, allowsAllAgents: Bool, trustedAgents: [TrustedAgent], grants: [FolderGrant]) {
        self.isEnabled = isEnabled
        self.allowsAllAgents = allowsAllAgents
        self.trustedAgents = trustedAgents
        self.grants = grants
    }
}
