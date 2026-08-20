import XCTest
@testable import AgentGrantAudit

final class GrantAuditorTests: XCTestCase {

    private let now = DemoFixtures.referenceNow
    private var auditor: GrantAuditor { GrantAuditor(policy: DemoFixtures.policy) }

    private func status(_ json: String) throws -> MCPServerStatus {
        try StatusDecoder.decode(Data(json.utf8))
    }

    private func document(permittedFolders: String, enabled: Bool = true) -> String {
        """
        {"running":true,"openWorkspaces":[],"permission":{
          "enabled":\(enabled),"unsafeAlwaysAllowAllAgents":false,
          "permittedAgents":[],"permittedFolders":[\(permittedFolders)]}}
        """
    }

    func testAProvisionedMachinePasses() throws {
        let report = auditor.audit(try status(DemoFixtures.provisioned), now: now)
        XCTAssertTrue(report.passes)
        XCTAssertEqual(report.exitCode, 0)
        XCTAssertEqual(report.findings.map(\.code), [.configurationClean])
    }

    func testAGrantAboveTheRepositoryRootBlocks() throws {
        let report = auditor.audit(try status(DemoFixtures.homeDirectoryGrant), now: now)
        XCTAssertFalse(report.passes)
        XCTAssertEqual(report.exitCode, 1)
        XCTAssertTrue(report.findings.contains { $0.code == .grantOutsideApprovedRoots })
        XCTAssertTrue(report.findings.contains { $0.code == .nonExpiringGrant })
    }

    func testAnUnapprovedTeamIdentifierBlocks() throws {
        let report = auditor.audit(try status(DemoFixtures.homeDirectoryGrant), now: now)
        let untrusted = report.findings.filter { $0.code == .untrustedTeamIdentifier }
        XCTAssertEqual(untrusted.count, 1)
        XCTAssertTrue(untrusted[0].detail.contains("ZZ99TESTTEAM"))
        XCTAssertEqual(untrusted[0].severity, .blocking)
        XCTAssertTrue(untrusted[0].remediation.contains("0C6F1B22-77A1-4C0E-93B7-2C4E2E9B4A10"),
                      "remediation must name the grant id you actually revoke")
    }

    func testTheBypassBlocksEvenThoughNothingIsListed() throws {
        let decoded = try status(DemoFixtures.machineWideBypass)
        XCTAssertTrue(decoded.permittedFolders.isEmpty)
        XCTAssertTrue(decoded.permittedAgents.isEmpty)

        let report = auditor.audit(decoded, now: now)
        XCTAssertFalse(report.passes, "an empty permittedFolders array must not read as a clean machine")
        XCTAssertEqual(report.findings.map(\.code), [.machineWideBypassEnabled])
        XCTAssertEqual(report.worstSeverity, .blocking)
    }

    func testAnExpiredGrantIsReportedButHarmless() throws {
        let json = document(permittedFolders: #"{"id":"E1","subtreeRoot":"/Users/rajat/Developer","expiresAt":1786000000}"#)
        let report = auditor.audit(try status(json), now: now)
        XCTAssertTrue(report.passes)
        XCTAssertEqual(report.findings.map(\.code), [.grantAlreadyExpired])
    }

    func testAGrantExactlyAtTheLifetimeCeilingIsAccepted() throws {
        let ceiling = now.addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
        let json = document(permittedFolders: """
        {"id":"C1","subtreeRoot":"/Users/rajat/Developer/checkout-ios","expiresAt":\(ceiling)}
        """)
        XCTAssertEqual(auditor.audit(try status(json), now: now).findings.map(\.code), [.configurationClean])
    }

    func testAGrantOneSecondOverTheCeilingWarns() throws {
        let over = now.addingTimeInterval(24 * 60 * 60 + 1).timeIntervalSince1970
        let json = document(permittedFolders: """
        {"id":"C2","subtreeRoot":"/Users/rajat/Developer/checkout-ios","expiresAt":\(over)}
        """)
        let report = auditor.audit(try status(json), now: now)
        XCTAssertEqual(report.findings.map(\.code), [.grantLifetimeExceedsPolicy])
        XCTAssertTrue(report.passes, "over-long is a warning, not a build stop")
    }

    func testADisabledServiceIsInformationalAndDoesNotHideItsGrants() throws {
        let json = document(
            permittedFolders: #"{"id":"D1","subtreeRoot":"/Users/rajat/Developer"}"#,
            enabled: false
        )
        let report = auditor.audit(try status(json), now: now)
        XCTAssertTrue(report.findings.contains { $0.code == .serviceDisabled })
        XCTAssertTrue(report.findings.contains { $0.code == .grantOutsideApprovedRoots })
        XCTAssertFalse(report.passes)
    }

    func testWorstSeverityWins() throws {
        let report = auditor.audit(try status(DemoFixtures.homeDirectoryGrant), now: now)
        XCTAssertEqual(report.worstSeverity, .blocking)
        XCTAssertTrue(report.findings.contains { $0.severity == .warning })
        XCTAssertEqual(report.findings(atLeast: .warning).count, report.findings.count)
    }

    func testEveryFindingCarriesARemediation() throws {
        for fixture in [DemoFixtures.provisioned, DemoFixtures.homeDirectoryGrant, DemoFixtures.machineWideBypass] {
            let report = auditor.audit(try status(fixture), now: now)
            for finding in report.findings {
                XCTAssertFalse(finding.remediation.isEmpty, "\(finding.code.rawValue) has no remediation")
            }
        }
    }

    func testAnEmptyApprovedTeamSetTrustsNobody() throws {
        let strict = TrustPolicy(approvedTeamIdentifiers: [], approvedGrantRoots: DemoFixtures.policy.approvedGrantRoots)
        let report = GrantAuditor(policy: strict).audit(try status(DemoFixtures.provisioned), now: now)
        XCTAssertEqual(report.findings.map(\.code), [.untrustedTeamIdentifier])
    }
}
