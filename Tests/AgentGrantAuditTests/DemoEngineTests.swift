import XCTest
@testable import AgentGrantAudit

final class DemoEngineTests: XCTestCase {

    func testProvisionedScenarioPassesAndReportsTwoReachableProjects() {
        let presentation = DemoEngine.present(.provisioned)
        XCTAssertTrue(presentation.passes)
        XCTAssertEqual(presentation.headline, "2 of 12 projects reachable.")
        XCTAssertNil(presentation.refusal)
    }

    func testHomeDirectoryScenarioFailsAndReportsNineReachableProjects() {
        let presentation = DemoEngine.present(.homeDirectory)
        XCTAssertFalse(presentation.passes)
        XCTAssertEqual(presentation.headline, "9 of 12 projects reachable.")
        XCTAssertEqual(presentation.blastRadius?.projectCount, 9)
    }

    func testBypassScenarioReportsZeroGrantsAndTotalReach() {
        let presentation = DemoEngine.present(.bypass)
        XCTAssertTrue(presentation.bypassActive)
        XCTAssertEqual(presentation.listedGrantCount, 0)
        XCTAssertEqual(presentation.headline, "0 grants listed. All 12 projects reachable.")
        XCTAssertFalse(presentation.passes)
    }

    func testSchemaDriftScenarioIsRefusedNotGraded() {
        let presentation = DemoEngine.present(.schemaDrift)
        XCTAssertNil(presentation.report)
        XCTAssertFalse(presentation.passes)
        XCTAssertEqual(presentation.headline, "Refused to grade this status document")
        XCTAssertTrue(presentation.refusal?.contains("allowAllAgents") == true)
    }

    func testEveryScenarioIdIsUnique() {
        XCTAssertEqual(Set(DemoScenario.all.map(\.id)).count, DemoScenario.all.count)
    }

    func testEveryScenarioProducesAHeadline() {
        for scenario in DemoScenario.all {
            XCTAssertFalse(DemoEngine.present(scenario).headline.isEmpty)
        }
    }
}
