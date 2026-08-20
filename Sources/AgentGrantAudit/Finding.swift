import Foundation

/// Ordered so a report can take the worst finding and turn it into an exit code.
public enum Severity: Int, Comparable, Sendable, CustomStringConvertible {
    case info = 0
    case warning = 1
    case blocking = 2

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String {
        switch self {
        case .info: return "info"
        case .warning: return "warning"
        case .blocking: return "blocking"
        }
    }
}

/// A single thing the audit noticed, with the remediation attached.
///
/// The remediation is part of the value, not an afterthought: a gate that fails
/// a build without saying what to type is a gate people learn to disable.
public struct Finding: Equatable, Sendable, Identifiable {
    public let code: Code
    public let severity: Severity
    public let detail: String
    public let remediation: String

    public var id: String { "\(code.rawValue)|\(detail)" }

    public enum Code: String, Sendable {
        case machineWideBypassEnabled
        case untrustedTeamIdentifier
        case grantOutsideApprovedRoots
        case nonExpiringGrant
        case grantLifetimeExceedsPolicy
        case grantAlreadyExpired
        case serviceDisabled
        case configurationClean
    }

    public init(code: Code, severity: Severity, detail: String, remediation: String) {
        self.code = code
        self.severity = severity
        self.detail = detail
        self.remediation = remediation
    }
}

/// The result of one audit.
public struct AuditReport: Equatable, Sendable {
    public let findings: [Finding]

    public init(findings: [Finding]) {
        self.findings = findings
    }

    public var worstSeverity: Severity {
        findings.map(\.severity).max() ?? .info
    }

    public var passes: Bool { worstSeverity < .blocking }

    /// `0` when the configuration is acceptable, `1` when a build should stop.
    public var exitCode: Int32 { passes ? 0 : 1 }

    public func findings(atLeast severity: Severity) -> [Finding] {
        findings.filter { $0.severity >= severity }
    }
}
