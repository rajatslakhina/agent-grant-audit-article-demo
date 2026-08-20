import Foundation

/// Grades a decoded status document against a committed policy.
///
/// `now` is a parameter rather than a call to `Date()` inside the type, so that
/// expiry behaviour is testable at an instant of the test's choosing instead of
/// whenever CI happens to run.
public struct GrantAuditor: Sendable {
    public let policy: TrustPolicy

    public init(policy: TrustPolicy) {
        self.policy = policy
    }

    public func audit(_ status: MCPServerStatus, now: Date) -> AuditReport {
        var findings: [Finding] = []

        if status.allowsAllAgents {
            findings.append(
                Finding(
                    code: .machineWideBypassEnabled,
                    severity: .blocking,
                    detail: """
                        The machine-wide bypass is on. Every process on this Mac is trusted, \
                        and because the bypass is not itself a grant, the grant list stays \
                        empty — so an audit that only reads grants sees the safest-looking \
                        configuration this machine can produce.
                        """,
                    remediation: "Disable and re-enable the service, or clear its permissions, then re-grant per repository."
                )
            )
        }

        if !status.isEnabled {
            findings.append(
                Finding(
                    code: .serviceDisabled,
                    severity: .info,
                    detail: "The service is disabled, so no agent can connect right now. Grants below persist and take effect again the moment it is re-enabled.",
                    remediation: "No action required; the grants are still worth reviewing."
                )
            )
        }

        for agent in status.trustedAgents where !policy.approvedTeamIdentifiers.contains(agent.teamIdentifier) {
            findings.append(
                Finding(
                    code: .untrustedTeamIdentifier,
                    severity: .blocking,
                    detail: "Agent '\(agent.signingIdentifier)' is trusted under team identifier \(agent.teamIdentifier), which is not in the approved set.",
                    remediation: "Add \(agent.teamIdentifier) to approvedTeamIdentifiers in review, or revoke the agent."
                )
            )
        }

        for grant in status.grants {
            if grant.expiry.hasExpired(at: now) {
                findings.append(
                    Finding(
                        code: .grantAlreadyExpired,
                        severity: .info,
                        detail: "Grant on \(grant.scope) has expired and no longer admits anything.",
                        remediation: "No action required."
                    )
                )
                continue
            }

            if !policy.approvesRoot(of: grant.scope) {
                findings.append(
                    Finding(
                        code: .grantOutsideApprovedRoots,
                        severity: .blocking,
                        detail: "Grant on \(grant.scope) is not contained by any approved root. A \(grant.reach == .recursive ? "recursive" : "single-directory") grant here reaches code this policy never reviewed.",
                        remediation: "Re-scope the grant to a repository root listed in approvedGrantRoots."
                    )
                )
            }

            switch grant.expiry {
            case .never where !policy.permitsNonExpiringGrants:
                findings.append(
                    Finding(
                        code: .nonExpiringGrant,
                        severity: .warning,
                        detail: "Grant on \(grant.scope) never expires. It outlives the task that needed it, the branch it was taken for, and usually the person who clicked it.",
                        remediation: "Re-take the grant with the 24-hour option, or set permitsNonExpiringGrants deliberately."
                    )
                )
            case .at(let instant) where instant.timeIntervalSince(now) > policy.maximumGrantLifetime:
                findings.append(
                    Finding(
                        code: .grantLifetimeExceedsPolicy,
                        severity: .warning,
                        detail: "Grant on \(grant.scope) has \(Int(instant.timeIntervalSince(now) / 3600))h left, over the \(Int(policy.maximumGrantLifetime / 3600))h ceiling.",
                        remediation: "Shorten the grant or raise maximumGrantLifetime in review."
                    )
                )
            default:
                break
            }
        }

        if findings.isEmpty {
            findings.append(
                Finding(
                    code: .configurationClean,
                    severity: .info,
                    detail: "Every trusted agent matches an approved team identifier and every live grant sits inside an approved root.",
                    remediation: "No action required."
                )
            )
        }

        return AuditReport(findings: findings)
    }
}
