import Foundation

/// Why a status document was refused.
public enum StatusDecodingError: Error, Equatable, CustomStringConvertible {
    /// A field the verdict depends on was absent.
    case missingSecurityRelevantField(String)
    /// A field was present with a type or value the decoder does not understand.
    case unreadableValue(field: String, found: String)
    /// A grant path was relative, empty, or escaped the filesystem root.
    case malformedGrantPath(String)
    /// The top level was not a JSON object.
    case notAnObject

    public var description: String {
        switch self {
        case .missingSecurityRelevantField(let field):
            return "missing security-relevant field '\(field)' — refusing to assume a default"
        case .unreadableValue(let field, let found):
            return "field '\(field)' held an unreadable value: \(found)"
        case .malformedGrantPath(let path):
            return "grant path is not an absolute normalised path: '\(path)'"
        case .notAnObject:
            return "status document is not a JSON object"
        }
    }
}

/// Decodes the JSON emitted by the local agent-authorisation service.
///
/// Deliberately strict. Every field the verdict depends on is required, and a
/// document missing one is refused rather than defaulted. That is a real cost:
/// this decoder breaks the first time the vendor renames a key, and the gate
/// goes red on a machine that was never actually misconfigured.
///
/// It is still the right trade. The alternative failure — a renamed key
/// silently decoding to `false`, the bypass going unnoticed, and the gate
/// reporting green — is the one that does damage, because nothing about it
/// looks like a failure. A security gate should be noisy and wrong rather than
/// quiet and wrong.
///
/// The schema below matches the fields reported in public write-ups of
/// `xcrun mcp-server status --format json`. Apple does not document it, which
/// is itself the argument for pinning expectations in code you own.
public enum StatusDecoder {

    public static func decode(_ data: Data, defaultReach: GrantScope = .recursive) throws -> MCPServerStatus {
        let parsed = try JSONSerialization.jsonObject(with: data)
        guard let object = parsed as? [String: Any] else { throw StatusDecodingError.notAnObject }

        let isEnabled = try requiredBool(object, "enabled")
        let allowsAll = try requiredBool(object, "allowAllAgents")

        var agents: [TrustedAgent] = []
        for entry in try requiredArray(object, "agents") {
            guard let row = entry as? [String: Any] else {
                throw StatusDecodingError.unreadableValue(field: "agents", found: String(describing: entry))
            }
            agents.append(
                TrustedAgent(
                    signingIdentifier: try requiredString(row, "signingIdentifier"),
                    teamIdentifier: try requiredString(row, "teamIdentifier")
                )
            )
        }

        var grants: [FolderGrant] = []
        for entry in try requiredArray(object, "folderGrants") {
            guard let row = entry as? [String: Any] else {
                throw StatusDecodingError.unreadableValue(field: "folderGrants", found: String(describing: entry))
            }
            let rawPath = try requiredString(row, "path")
            guard let scope = PathScope(rawPath) else {
                throw StatusDecodingError.malformedGrantPath(rawPath)
            }
            let reach: GrantScope
            if let rawReach = row["reach"] {
                guard let text = rawReach as? String, let parsedReach = GrantScope(rawValue: text) else {
                    throw StatusDecodingError.unreadableValue(field: "reach", found: String(describing: rawReach))
                }
                reach = parsedReach
            } else {
                reach = defaultReach
            }
            grants.append(FolderGrant(scope: scope, reach: reach, expiry: try expiry(from: row)))
        }

        return MCPServerStatus(
            isEnabled: isEnabled,
            allowsAllAgents: allowsAll,
            trustedAgents: agents,
            grants: grants
        )
    }

    /// An absent `expiresAt` means a permanent grant, and is the documented
    /// default when the user does not pick *Allow for 24 Hours*. It is the one
    /// absence this decoder is willing to interpret, because the interpretation
    /// is the pessimistic one.
    private static func expiry(from row: [String: Any]) throws -> GrantExpiry {
        guard let raw = row["expiresAt"], !(raw is NSNull) else { return .never }
        if let seconds = raw as? Double { return .at(Date(timeIntervalSince1970: seconds)) }
        if let text = raw as? String, let parsed = ISO8601DateFormatter().date(from: text) { return .at(parsed) }
        throw StatusDecodingError.unreadableValue(field: "expiresAt", found: String(describing: raw))
    }

    private static func requiredBool(_ object: [String: Any], _ key: String) throws -> Bool {
        guard let raw = object[key] else { throw StatusDecodingError.missingSecurityRelevantField(key) }
        guard let value = raw as? Bool else {
            throw StatusDecodingError.unreadableValue(field: key, found: String(describing: raw))
        }
        return value
    }

    private static func requiredString(_ object: [String: Any], _ key: String) throws -> String {
        guard let raw = object[key] else { throw StatusDecodingError.missingSecurityRelevantField(key) }
        guard let value = raw as? String, !value.isEmpty else {
            throw StatusDecodingError.unreadableValue(field: key, found: String(describing: raw))
        }
        return value
    }

    private static func requiredArray(_ object: [String: Any], _ key: String) throws -> [Any] {
        guard let raw = object[key] else { throw StatusDecodingError.missingSecurityRelevantField(key) }
        guard let value = raw as? [Any] else {
            throw StatusDecodingError.unreadableValue(field: key, found: String(describing: raw))
        }
        return value
    }
}
