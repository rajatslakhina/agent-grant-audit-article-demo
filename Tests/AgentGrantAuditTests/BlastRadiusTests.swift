import XCTest
@testable import AgentGrantAudit

final class BlastRadiusTests: XCTestCase {

    private let now = DemoFixtures.referenceNow
    private let projects = DemoFixtures.discoveredProjects

    private func folder(_ path: String, _ expiry: GrantExpiry = .never) -> PermittedFolder {
        PermittedFolder(id: "id-\(path)", subtreeRoot: PathScope(path) ?? .root, expiry: expiry)
    }

    func testOneSubtreeRootOnTheParentFolderReachesNineOfTwelveProjects() {
        let grant = folder("/Users/rajat/Developer")
        let radius = BlastRadius.measure(folders: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 9)
        XCTAssertEqual(radius.widestGrant, grant)
        XCTAssertFalse(radius.reachableProjects.contains(PathScope("/Users/rajat/Clients/acme/Acme.xcodeproj") ?? .root))
    }

    func testARepositoryScopedGrantReachesOnlyThatRepository() {
        let grant = folder("/Users/rajat/Developer/checkout-ios", .at(now.addingTimeInterval(3600)))
        XCTAssertEqual(BlastRadius.measure(folders: [grant], projects: projects, now: now).projectCount, 2)
    }

    func testAnExpiredGrantReachesNothing() {
        let grant = folder("/Users/rajat/Developer", .at(now.addingTimeInterval(-1)))
        let radius = BlastRadius.measure(folders: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 0)
        XCTAssertNil(radius.widestGrant)
    }

    func testAGrantExpiringExactlyNowIsAlreadyGone() {
        let grant = folder("/Users/rajat/Developer", .at(now))
        XCTAssertTrue(grant.expiry.hasExpired(at: now))
        XCTAssertEqual(BlastRadius.measure(folders: [grant], projects: projects, now: now).projectCount, 0)
    }

    func testOverlappingGrantsCountEachProjectOnce() {
        let outer = folder("/Users/rajat/Developer")
        let inner = folder("/Users/rajat/Developer/wallet-core")
        let radius = BlastRadius.measure(folders: [outer, inner], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 9)
        XCTAssertEqual(radius.widestGrant, outer)
    }

    func testAGrantOnTheRootReachesEverything() {
        let grant = PermittedFolder(id: "root", subtreeRoot: .root, expiry: .never)
        XCTAssertEqual(
            BlastRadius.measure(folders: [grant], projects: projects, now: now).projectCount,
            projects.count
        )
    }

    func testNoGrantsReachNothing() {
        let radius = BlastRadius.measure(folders: [], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 0)
        XCTAssertNil(radius.widestGrant)
    }

    func testReachableProjectsAreSortedDeterministically() {
        let grant = folder("/Users/rajat/Developer")
        let radius = BlastRadius.measure(folders: [grant], projects: projects.reversed(), now: now)
        XCTAssertEqual(radius.reachableProjects, radius.reachableProjects.sorted { $0.description < $1.description })
    }

    func testASiblingDirectorySharingAPrefixIsNotReached() {
        // /Users/rajat/Dev would prefix-match /Users/rajat/Developer as a string.
        let grant = folder("/Users/rajat/Dev")
        XCTAssertEqual(BlastRadius.measure(folders: [grant], projects: projects, now: now).projectCount, 0)
    }
}
