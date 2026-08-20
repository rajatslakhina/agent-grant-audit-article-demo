import XCTest
@testable import AgentGrantAudit

final class BlastRadiusTests: XCTestCase {

    private let now = DemoFixtures.referenceNow
    private let projects = DemoFixtures.discoveredProjects

    func testOneRecursiveGrantOnTheParentFolderReachesNineOfTwelveProjects() {
        let grant = FolderGrant(scope: PathScope("/Users/rajat/Developer")!, reach: .recursive, expiry: .never)
        let radius = BlastRadius.measure(grants: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 9)
        XCTAssertEqual(radius.widestGrant, grant)
        XCTAssertFalse(radius.reachableProjects.contains(PathScope("/Users/rajat/Clients/acme/Acme.xcodeproj")!))
    }

    func testARepositoryScopedGrantReachesOnlyThatRepository() {
        let grant = FolderGrant(
            scope: PathScope("/Users/rajat/Developer/checkout-ios")!,
            reach: .recursive,
            expiry: .at(now.addingTimeInterval(3600))
        )
        let radius = BlastRadius.measure(grants: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 2)
    }

    func testADirectoryOnlyGrantDoesNotReachNestedProjects() {
        let grant = FolderGrant(
            scope: PathScope("/Users/rajat/Developer/experiments")!,
            reach: .directoryOnly,
            expiry: .never
        )
        let radius = BlastRadius.measure(grants: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.reachableProjects.map(\.description), ["/Users/rajat/Developer/experiments/Spike.xcodeproj"])
    }

    func testAnExpiredGrantReachesNothing() {
        let grant = FolderGrant(
            scope: PathScope("/Users/rajat/Developer")!,
            reach: .recursive,
            expiry: .at(now.addingTimeInterval(-1))
        )
        let radius = BlastRadius.measure(grants: [grant], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 0)
        XCTAssertNil(radius.widestGrant)
    }

    func testAGrantExpiringExactlyNowIsAlreadyGone() {
        let grant = FolderGrant(scope: PathScope("/Users/rajat/Developer")!, reach: .recursive, expiry: .at(now))
        XCTAssertTrue(grant.expiry.hasExpired(at: now))
        XCTAssertEqual(BlastRadius.measure(grants: [grant], projects: projects, now: now).projectCount, 0)
    }

    func testOverlappingGrantsCountEachProjectOnce() {
        let outer = FolderGrant(scope: PathScope("/Users/rajat/Developer")!, reach: .recursive, expiry: .never)
        let inner = FolderGrant(scope: PathScope("/Users/rajat/Developer/wallet-core")!, reach: .recursive, expiry: .never)
        let radius = BlastRadius.measure(grants: [outer, inner], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 9)
        XCTAssertEqual(radius.widestGrant, outer)
    }

    func testAGrantOnTheRootReachesEverything() {
        let grant = FolderGrant(scope: .root, reach: .recursive, expiry: .never)
        XCTAssertEqual(BlastRadius.measure(grants: [grant], projects: projects, now: now).projectCount, projects.count)
    }

    func testNoGrantsReachNothing() {
        let radius = BlastRadius.measure(grants: [], projects: projects, now: now)
        XCTAssertEqual(radius.projectCount, 0)
        XCTAssertNil(radius.widestGrant)
    }

    func testReachableProjectsAreSortedDeterministically() {
        let grant = FolderGrant(scope: PathScope("/Users/rajat/Developer")!, reach: .recursive, expiry: .never)
        let radius = BlastRadius.measure(grants: [grant], projects: projects.reversed(), now: now)
        XCTAssertEqual(radius.reachableProjects, radius.reachableProjects.sorted { $0.description < $1.description })
    }
}
