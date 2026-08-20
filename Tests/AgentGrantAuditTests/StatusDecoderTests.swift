import XCTest
@testable import AgentGrantAudit

final class StatusDecoderTests: XCTestCase {

    private func decode(_ json: String) throws -> MCPServerStatus {
        try StatusDecoder.decode(Data(json.utf8))
    }

    private func status(permission: String) -> String {
        """
        {"running":true,"openWorkspaces":[],"permission":\(permission)}
        """
    }

    func testDecodesAProvisionedDocument() throws {
        let status = try decode(DemoFixtures.provisioned)
        XCTAssertTrue(status.isEnabled)
        XCTAssertTrue(status.isRunning)
        XCTAssertFalse(status.allowsAllAgents)
        XCTAssertEqual(status.permittedAgents.count, 1)
        XCTAssertEqual(status.permittedAgents.first?.teamIdentifier, "Q6L2SF6YDW")
        XCTAssertEqual(status.permittedAgents.first?.signingIdentifier, "com.anthropic.claude-code")
        XCTAssertEqual(status.permittedFolders.count, 1)
        XCTAssertEqual(status.permittedFolders.first?.subtreeRoot, PathScope("/Users/rajat/Developer/checkout-ios"))
        XCTAssertEqual(status.permittedFolders.first?.expiry, .at(Date(timeIntervalSince1970: 1_787_043_200)))
    }

    func testARenamedBypassFieldIsRefusedRatherThanDefaultedToFalse() {
        // The whole reason the decoder is strict: a renamed key must not read as "safe".
        XCTAssertThrowsError(try decode(DemoFixtures.schemaDrift)) { error in
            XCTAssertEqual(
                error as? StatusDecodingError,
                .missingSecurityRelevantField("unsafeAlwaysAllowAllAgents")
            )
        }
    }

    func testAMissingPermissionObjectIsRefused() {
        XCTAssertThrowsError(try decode(#"{"running":true,"openWorkspaces":[]}"#)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .missingSecurityRelevantField("permission"))
        }
    }

    func testAnUnknownTrustVariantIsRefusedNotTreatedAsTrusted() {
        // `trust` is a tagged union. A future variant must not decode to
        // "trusted, details unknown".
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,
         "permittedAgents":[{"id":"X","trust":{"attested":{"nonce":"abc"}}}],
         "permittedFolders":[]}
        """)
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .unknownTrustKind("attested"))
        }
    }

    func testATrustObjectWithTwoVariantsIsRefused() {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,
         "permittedAgents":[{"id":"X","trust":{"signed":{"signingIdentifier":"a","teamIdentifier":"b"},"attested":{}}}],
         "permittedFolders":[]}
        """)
        XCTAssertThrowsError(try decode(json))
    }

    func testAnAbsentExpiryMeansPermanentNotUnknown() throws {
        let status = try decode(DemoFixtures.homeDirectoryGrant)
        XCTAssertEqual(status.permittedFolders.first?.expiry, .never)
    }

    func testAnExplicitNullExpiryAlsoMeansPermanent() throws {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,"permittedAgents":[],
         "permittedFolders":[{"id":"X","subtreeRoot":"/a","expiresAt":null}]}
        """)
        XCTAssertEqual(try decode(json).permittedFolders.first?.expiry, .never)
    }

    func testAnISO8601ExpiryIsAccepted() throws {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,"permittedAgents":[],
         "permittedFolders":[{"id":"X","subtreeRoot":"/a","expiresAt":"2026-08-20T12:00:00Z"}]}
        """)
        guard case .at(let instant)? = try decode(json).permittedFolders.first?.expiry else {
            return XCTFail("expected a dated expiry")
        }
        XCTAssertEqual(instant.timeIntervalSince1970, 1_787_227_200, accuracy: 1)
    }

    func testAnUnreadableExpiryIsRefused() {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,"permittedAgents":[],
         "permittedFolders":[{"id":"X","subtreeRoot":"/a","expiresAt":"soon"}]}
        """)
        XCTAssertThrowsError(try decode(json))
    }

    func testARelativeSubtreeRootIsRefused() {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,"permittedAgents":[],
         "permittedFolders":[{"id":"X","subtreeRoot":"Developer"}]}
        """)
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .malformedSubtreeRoot("Developer"))
        }
    }

    func testAnEmptySigningIdentifierIsRefused() {
        let json = status(permission: """
        {"enabled":true,"unsafeAlwaysAllowAllAgents":false,
         "permittedAgents":[{"id":"X","trust":{"signed":{"signingIdentifier":"","teamIdentifier":"Q6L2SF6YDW"}}}],
         "permittedFolders":[]}
        """)
        XCTAssertThrowsError(try decode(json))
    }

    func testAWrongTypeIsRefusedRatherThanCoerced() {
        let json = status(permission: """
        {"enabled":"true","unsafeAlwaysAllowAllAgents":false,"permittedAgents":[],"permittedFolders":[]}
        """)
        XCTAssertThrowsError(try decode(json)) { error in
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

    func testAMissingRunningFlagIsRefused() {
        let json = """
        {"openWorkspaces":[],"permission":{"enabled":true,"unsafeAlwaysAllowAllAgents":false,
         "permittedAgents":[],"permittedFolders":[]}}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? StatusDecodingError, .missingSecurityRelevantField("running"))
        }
    }
}
