import XCTest
@testable import AgentGrantAudit

final class PathScopeTests: XCTestCase {

    func testSiblingDirectoryWithASharedPrefixIsNotContained() {
        // The bug a string-prefix implementation ships with.
        let dev = PathScope("/Users/r/Dev")!
        let devious = PathScope("/Users/r/Devious")!
        XCTAssertTrue("/Users/r/Devious".hasPrefix("/Users/r/Dev"), "precondition: the naive check says yes")
        XCTAssertFalse(dev.contains(devious))
    }

    func testDescendantsAreContainedAtAnyDepth() {
        let dev = PathScope("/Users/r/Dev")!
        XCTAssertTrue(dev.contains(PathScope("/Users/r/Dev/app/Sub/App.xcodeproj")!))
        XCTAssertEqual(dev.depth(of: PathScope("/Users/r/Dev/app/Sub/App.xcodeproj")!), 3)
    }

    func testAScopeContainsItself() {
        let dev = PathScope("/Users/r/Dev")!
        XCTAssertTrue(dev.contains(dev))
        XCTAssertEqual(dev.depth(of: dev), 0)
    }

    func testTrailingSlashesAndDoubledSeparatorsNormalise() {
        XCTAssertEqual(PathScope("/Users/r/Dev/"), PathScope("/Users/r/Dev"))
        XCTAssertEqual(PathScope("//Users//r///Dev"), PathScope("/Users/r/Dev"))
        XCTAssertEqual(PathScope("/Users/./r/Dev"), PathScope("/Users/r/Dev"))
    }

    func testDotDotIsResolvedLexically() {
        XCTAssertEqual(PathScope("/Users/r/Dev/../Dev"), PathScope("/Users/r/Dev"))
        XCTAssertEqual(PathScope("/Users/r/Dev/sub/.."), PathScope("/Users/r/Dev"))
    }

    func testPathsThatEscapeTheRootAreRejectedRatherThanClamped() {
        XCTAssertNil(PathScope("/.."))
        XCTAssertNil(PathScope("/Users/../.."))
    }

    func testRelativePathsAreRejected() {
        XCTAssertNil(PathScope("Users/r/Dev"))
        XCTAssertNil(PathScope(""))
        XCTAssertNil(PathScope("~/Developer"))
    }

    func testRootContainsEverythingAndHasNoParent() {
        XCTAssertTrue(PathScope.root.contains(PathScope("/Users/r/Dev")!))
        XCTAssertNil(PathScope.root.parent)
        XCTAssertEqual(PathScope.root.description, "/")
    }

    func testParentDropsExactlyOneComponent() {
        XCTAssertEqual(PathScope("/Users/r/Dev")!.parent, PathScope("/Users/r"))
        XCTAssertEqual(PathScope("/Users")!.parent, PathScope.root)
    }

    func testDepthIsNilWhenNotContained() {
        XCTAssertNil(PathScope("/Users/r/Dev")!.depth(of: PathScope("/Users/r")!))
    }
}
