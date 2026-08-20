import Foundation

/// When a folder grant stops being honoured.
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

/// An agent the headless service has been told to trust.
///
/// The service records a code signature rather than a process name — the
/// genuinely good half of the design, because `teamIdentifier` is verifiable,
/// scriptable and provisionable, so a build script can assert it before it runs.
public struct PermittedAgent: Equatable, Sendable {
    /// The grant id. This is what you revoke.
    public let id: String
    public let signingIdentifier: String
    public let teamIdentifier: String

    public init(id: String, signingIdentifier: String, teamIdentifier: String) {
        self.id = id
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

/// A folder the user has handed to agents.
///
/// The service calls this field `subtreeRoot`, and the name is the whole story:
/// the grant covers the folder and everything beneath it, to any depth.
public struct PermittedFolder: Equatable, Sendable {
    public let id: String
    public let subtreeRoot: PathScope
    public let expiry: GrantExpiry

    public init(id: String, subtreeRoot: PathScope, expiry: GrantExpiry) {
        self.id = id
        self.subtreeRoot = subtreeRoot
        self.expiry = expiry
    }

    /// `true` when this grant would admit an agent to `project`.
    public func covers(_ project: PathScope, at now: Date) -> Bool {
        guard !expiry.hasExpired(at: now) else { return false }
        return subtreeRoot.contains(project)
    }
}

/// A decoded snapshot of the local agent-authorisation state.
public struct MCPServerStatus: Equatable, Sendable {
    public let isEnabled: Bool
    public let isRunning: Bool

    /// Whether the machine-wide bypass is active.
    ///
    /// This is the field that makes an empty `permittedFolders` array readable
    /// at all. Without it, "no folders" is ambiguous between *nothing is
    /// trusted* and *everything is trusted*, and those are opposite facts.
    public let allowsAllAgents: Bool
    public let permittedAgents: [PermittedAgent]
    public let permittedFolders: [PermittedFolder]

    public init(
        isEnabled: Bool,
        isRunning: Bool,
        allowsAllAgents: Bool,
        permittedAgents: [PermittedAgent],
        permittedFolders: [PermittedFolder]
    ) {
        self.isEnabled = isEnabled
        self.isRunning = isRunning
        self.allowsAllAgents = allowsAllAgents
        self.permittedAgents = permittedAgents
        self.permittedFolders = permittedFolders
    }
}
