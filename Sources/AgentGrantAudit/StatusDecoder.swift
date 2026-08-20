import Foundation

/// Why a status document was refused.
public enum StatusDecodingError: Error, Equatable, CustomStringConvertible {
    /// A field the verdict depends on was absent.
    case missingSecurityRelevantField(String)
    /// A field was present with a type or value the decoder does not understand.
    case unreadableValue(field: String, found: String)
    /// A `trust` object used a variant this decoder has never seen.
    case unknownTrustKind(String)
    /// A `subtreeRoot` was relative, empty, or escaped the filesystem root.
    case malformedSubtreeRoot(String)
    /// The top level was not a JSON object.
    case notAnObject

    public var description: String {
        switch self {
        case .missingSecurityRelevantField(let field):
            return "missing security-relevant field '\(field)' — refusing to assume a default"
        case .unreadableValue(let field, let found):
            return "field '\(field)' held an unreadable value: \(found)"
        case .unknownTrustKind(let kind):
            return "agent trust kind '\(kind)' is not one this build understands"
        case .malformedSubtreeRoot(let path):
            return "subtreeRoot is not an absolute normalised path: '\(path)'"
        case .notAnObject:
            return "status document is not a JSON object"
        }
    }
}

/// Decodes the JSON emitted by `xcrun mcp-server status --format json`.
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
/// The shape below follows the `status --format json` output published in
/// Artem Novichkov's write-up of Xcode 27 beta 5's headless MCP server. Apple
/// documents neither the schema nor the on-disk permissions file, and the CLI
/// surface is explicitly called out as beta — which is the argument for pinning
/// expectations in code you own, not a reason to skip checking.
public enum StatusDecoder {

    public static func decode(_ data: Data) throws -> MCPServerStatus {
        let parsed = try JSONSerialization.jsonObject(with: data)
        guard let root = parsed as? [String: Any] else { throw StatusDecodingError.notAnObject }

        let isRunning = try requiredBool(root, "running")
        guard let permission = root["permission"] as? [String: Any] else {
            throw StatusDecodingError.missingSecurityRelevantField("permission")
        }

        let isEnabled = try requiredBool(permission, "enabled")
        let allowsAll = try requiredBool(permission, "unsafeAlwaysAllowAllAgents")

        var agents: [PermittedAgent] = []
        for entry in try requiredArray(permission, "permittedAgents") {
            guard let row = entry as? [String: Any] else {
                throw StatusDecodingError.unreadableValue(field: "permittedAgents", found: String(describing: entry))
            }
            guard let trust = row["trust"] as? [String: Any] else {
                throw StatusDecodingError.missingSecurityRelevantField("trust")
            }
            // `trust` is a tagged union with exactly one key. Today the only
            // variant is `signed`. A future build that adds another must not
            // decode to "trusted, details unknown".
            guard let kind = trust.keys.first, trust.count == 1 else {
                throw StatusDecodingError.unreadableValue(field: "trust", found: String(describing: trust.keys.sorted()))
            }
            guard kind == "signed", let signed = trust["signed"] as? [String: Any] else {
                throw StatusDecodingError.unknownTrustKind(kind)
            }
            agents.append(
                PermittedAgent(
                    id: try requiredString(row, "id"),
                    signingIdentifier: try requiredString(signed, "signingIdentifier"),
                    teamIdentifier: try requiredString(signed, "teamIdentifier")
                )
            )
        }

        var folders: [PermittedFolder] = []
        for entry in try requiredArray(permission, "permittedFolders") {
            guard let row = entry as? [String: Any] else {
                throw StatusDecodingError.unreadableValue(field: "permittedFolders", found: String(describing: entry))
            }
            let raw = try requiredString(row, "subtreeRoot")
            guard let scope = PathScope(raw) else {
                throw StatusDecodingError.malformedSubtreeRoot(raw)
            }
            folders.append(
                PermittedFolder(id: try requiredString(row, "id"), subtreeRoot: scope, expiry: try expiry(from: row))
            )
        }

        return MCPServerStatus(
            isEnabled: isEnabled,
            isRunning: isRunning,
            allowsAllAgents: allowsAll,
            permittedAgents: agents,
            permittedFolders: folders
        )
    }

    /// An absent expiry means a permanent grant. That is the documented
    /// behaviour — the prompt does not expire unless the user actively picks
    /// *Allow for 24 Hours* — and it is the one absence this decoder is willing
    /// to interpret, because the interpretation is the pessimistic one.
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
