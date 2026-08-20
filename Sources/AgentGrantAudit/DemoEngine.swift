import Foundation

/// Everything the demo screen renders, computed without importing SwiftUI so it
/// can be asserted on directly.
public struct DemoPresentation: Equatable, Sendable {
    public let headline: String
    public let report: AuditReport?
    public let blastRadius: BlastRadius?
    public let bypassActive: Bool
    public let listedGrantCount: Int
    public let refusal: String?

    public var passes: Bool { report?.passes ?? false }

    public init(
        headline: String,
        report: AuditReport?,
        blastRadius: BlastRadius?,
        bypassActive: Bool,
        listedGrantCount: Int,
        refusal: String?
    ) {
        self.headline = headline
        self.report = report
        self.blastRadius = blastRadius
        self.bypassActive = bypassActive
        self.listedGrantCount = listedGrantCount
        self.refusal = refusal
    }
}

public enum DemoEngine {

    public static func present(
        _ scenario: DemoScenario,
        policy: TrustPolicy = DemoFixtures.policy,
        projects: [PathScope] = DemoFixtures.discoveredProjects,
        now: Date = DemoFixtures.referenceNow
    ) -> DemoPresentation {
        guard let data = scenario.json.data(using: .utf8) else {
            return DemoPresentation(
                headline: "Status document was not valid UTF-8",
                report: nil,
                blastRadius: nil,
                bypassActive: false,
                listedGrantCount: 0,
                refusal: "unreadable bytes"
            )
        }

        let status: MCPServerStatus
        do {
            status = try StatusDecoder.decode(data)
        } catch {
            let reason = (error as? StatusDecodingError)?.description ?? String(describing: error)
            return DemoPresentation(
                headline: "Refused to grade this status document",
                report: nil,
                blastRadius: nil,
                bypassActive: false,
                listedGrantCount: 0,
                refusal: reason
            )
        }

        let report = GrantAuditor(policy: policy).audit(status, now: now)
        let radius = BlastRadius.measure(grants: status.grants, projects: projects, now: now)

        let headline: String
        if status.allowsAllAgents {
            headline = "\(status.grants.count) grants listed. All \(projects.count) projects reachable."
        } else {
            headline = "\(radius.projectCount) of \(projects.count) projects reachable."
        }

        return DemoPresentation(
            headline: headline,
            report: report,
            blastRadius: radius,
            bypassActive: status.allowsAllAgents,
            listedGrantCount: status.grants.count,
            refusal: nil
        )
    }
}
