import XCTest
@testable import AgentGrantAudit

final class StatusDecoderTests: XCTestCase {

    private func decode(_ json: String) throws -> MCPServerStatus {
        try StatusDecoder.decode(Data(json.utf8))
    }

    func testDecodesAProvisionedDocument() throws {
        let status = try decode(DemoFixtures.provisioned)
        XCTAssertTrue(status.isEnabled)
        XCTAssertFalse(status.allowsAllAgents)
        XCTAssertEqual(status.trustedAgents.count, 1)
        XCTAssertEqual(status.trustedAgents.first?.teamIdentifier, "Q6L2SF6YDW")
        XCTAssertEqual(status.grants.count, 1)
        XCTAssertEqual(status.grants.first?.scope, PathScope("/Users/rajat/Developer/checkout-ios"))
        XCTAssertEqual(status.grants.first?.expiry, .at(Date(timeIntervalSince1970: 1_787_043_200)))
    }

    func testAMissingBypassFieldIsRefusedRatherThanDefaultedToFalse() {
        // The whole reason the decoder is strict: a renamed key must not read as "safe".
        XCTAssertThrowsError(try decode(DemoFixtures.schemaDrift)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .missingSecurityRelevantField("allowAllAgents"))
        }
    }

    func testAnAbsentExpiryMeansPermanentNotUnknown() throws {
        let status = try decode(DemoFixtures.homeDirectoryGrant)
        XCTAssertEqual(status.grants.first?.expiry, .never)
    }

    func testAnExplicitNullExpiryAlsoMeansPermanent() throws {
        let status = try decode("""
        {"enabled":true,"allowAllAgents":false,"agents":[],
         "folderGrants":[{"path":"/a","expiresAt":null}]}
        """)
        XCTAssertEqual(status.grants.first?.expiry, .never)
    }

    func testAnISO8601ExpiryIsAccepted() throws {
        let status = try decode("""
        {"enabled":true,"allowAllAgents":false,"agents":[],
         "folderGrants":[{"path":"/a","expiresAt":"2026-08-20T12:00:00Z"}]}
        """)
        guard case .at(let instant)? = status.grants.first?.expiry else {
            return XCTFail("expected a dated expiry")
        }
        XCTAssertEqual(instant.timeIntervalSince1970, 1_787_227_200, accuracy: 1)
    }

    func testAnUnreadableExpiryIsRefused() {
        XCTAssertThrowsError(try decode("""
        {"enabled":true,"allowAllAgents":false,"agents":[],
         "folderGrants":[{"path":"/a","expiresAt":"soon"}]}
        """))
    }

    func testARelativeGrantPathIsRefused() {
        XCTAssertThrowsError(try decode("""
        {"enabled":true,"allowAllAgents":false,"agents":[],"folderGrants":[{"path":"Developer"}]}
        """)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .malformedGrantPath("Developer"))
        }
    }

    func testAnEmptySigningIdentifierIsRefused() {
        XCTAssertThrowsError(try decode("""
        {"enabled":true,"allowAllAgents":false,
         "agents":[{"signingIdentifier":"","teamIdentifier":"Q6L2SF6YDW"}],"folderGrants":[]}
        """))
    }

    func testAWrongTypeIsRefusedRatherThanCoerced() {
        XCTAssertThrowsError(try decode("""
        {"enabled":"true","allowAllAgents":false,"agents":[],"folderGrants":[]}
        """)) { error in
            guard case .unreadableValue(let field, _)? = error as? StatusDecodingError else {
                return XCTFail("expected an unreadable-value error")
            }
            XCTAssertEqual(field, "enabled")
        }
    }

    func testAJSONArrayAtTopLevelIsRefused() {
        XCTAssertThrowsError(try decode("[]")) { error in
            XCTAssertEqual(error as? StatusDecodingError, .notAnObject)
        }
    }

    func testAnUnknownReachValueIsRefused() {
        XCTAssertThrowsError(try decode("""
        {"enabled":true,"allowAllAgents":false,"agents":[],
         "folderGrants":[{"path":"/a","reach":"whole-disk"}]}
        """))
    }
}
