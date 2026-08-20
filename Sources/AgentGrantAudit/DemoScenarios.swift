import Foundation

/// Fixtures shared by the demo app and the test suite, so the screen and the
/// assertions are grading the same bytes.
///
/// Every fixture follows the published `status --format json` shape: a
/// top-level `running` plus a `permission` object holding `enabled`,
/// `unsafeAlwaysAllowAllAgents`, `permittedAgents` (whose `trust` is a tagged
/// union) and `permittedFolders` (keyed by `subtreeRoot`).
///
/// One addition: `provisioned` carries an `expiresAt` the published output does
/// not show. It is inferred from the documented *Allow for 24 Hours* option so
/// the expiry paths have something to grade. Treat that field as speculative.
public enum DemoFixtures {

    /// A fixed instant, so every run of the demo and every test produces the
    /// same verdict regardless of when it executes.
    public static let referenceNow = Date(timeIntervalSince1970: 1_787_000_000)

    /// Twelve project paths of the kind a working machine accumulates.
    public static let discoveredProjects: [PathScope] = [
        "/Users/rajat/Developer/checkout-ios/Checkout.xcodeproj",
        "/Users/rajat/Developer/checkout-ios/Sandbox/Scratch.xcodeproj",
        "/Users/rajat/Developer/wallet-core/Wallet.xcodeproj",
        "/Users/rajat/Developer/wallet-core/Tools/Bench.xcodeproj",
        "/Users/rajat/Developer/identity-sdk/Identity.xcodeproj",
        "/Users/rajat/Developer/pricing-service/Pricing.xcodeproj",
        "/Users/rajat/Developer/experiments/Spike.xcodeproj",
        "/Users/rajat/Developer/experiments/old/Spike2.xcodeproj",
        "/Users/rajat/Developer/internal-tools/Ops.xcodeproj",
        "/Users/rajat/Clients/northwind/Northwind.xcodeproj",
        "/Users/rajat/Clients/acme/Acme.xcodeproj",
        "/Users/rajat/Archive/2019/Legacy.xcodeproj"
    ].compactMap(PathScope.init)

    /// The policy the fixtures are graded against: one repository root, one
    /// approved team identifier, nothing permanent.
    public static let policy = TrustPolicy(
        approvedTeamIdentifiers: ["Q6L2SF6YDW"],
        approvedGrantRoots: ["/Users/rajat/Developer/checkout-ios"].compactMap(PathScope.init),
        maximumGrantLifetime: 24 * 60 * 60,
        permitsNonExpiringGrants: false
    )

    /// Grant scoped to one repository, expiring in twelve hours. This is what
    /// the policy is asking for.
    public static let provisioned = """
    {
      "running": true,
      "openWorkspaces": [],
      "permission": {
        "enabled": true,
        "unsafeAlwaysAllowAllAgents": false,
        "permittedAgents": [
          {
            "id": "A843056C-42FA-4C26-9EB3-84A7251FF7F1",
            "trust": { "signed": { "signingIdentifier": "com.anthropic.claude-code", "teamIdentifier": "Q6L2SF6YDW" } }
          }
        ],
        "permittedFolders": [
          { "id": "026F9649-91E7-48B4-B9F4-947E91ACEB37",
            "subtreeRoot": "/Users/rajat/Developer/checkout-ios",
            "expiresAt": 1787043200 }
        ]
      }
    }
    """

    /// One click on the parent folder of everything. A subtree root, permanent.
    public static let homeDirectoryGrant = """
    {
      "running": true,
      "openWorkspaces": [],
      "permission": {
        "enabled": true,
        "unsafeAlwaysAllowAllAgents": false,
        "permittedAgents": [
          {
            "id": "A843056C-42FA-4C26-9EB3-84A7251FF7F1",
            "trust": { "signed": { "signingIdentifier": "com.anthropic.claude-code", "teamIdentifier": "Q6L2SF6YDW" } }
          },
          {
            "id": "0C6F1B22-77A1-4C0E-93B7-2C4E2E9B4A10",
            "trust": { "signed": { "signingIdentifier": "com.example.unknown-agent", "teamIdentifier": "ZZ99TESTTEAM" } }
          }
        ],
        "permittedFolders": [
          { "id": "5F0C4E1B-2B9E-4E0A-9D4B-6C1D8E2F3A44", "subtreeRoot": "/Users/rajat/Developer" }
        ]
      }
    }
    """

    /// The bypass. Note what is *not* here: any grant to revoke.
    public static let machineWideBypass = """
    {
      "running": true,
      "openWorkspaces": [],
      "permission": {
        "enabled": true,
        "unsafeAlwaysAllowAllAgents": true,
        "permittedAgents": [],
        "permittedFolders": []
      }
    }
    """

    /// A document from a build that renamed the field the verdict depends on.
    public static let schemaDrift = """
    {
      "running": true,
      "openWorkspaces": [],
      "permission": {
        "enabled": true,
        "allowAllAgents": false,
        "permittedAgents": [],
        "permittedFolders": []
      }
    }
    """
}

/// One selectable case in the demo app.
public struct DemoScenario: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let json: String

    public init(id: String, title: String, subtitle: String, json: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.json = json
    }

    public static let provisioned = DemoScenario(
        id: "provisioned",
        title: "Provisioned",
        subtitle: "One repository, twelve hours",
        json: DemoFixtures.provisioned
    )

    public static let homeDirectory = DemoScenario(
        id: "home",
        title: "One folder up",
        subtitle: "Subtree root on ~/Developer",
        json: DemoFixtures.homeDirectoryGrant
    )

    public static let bypass = DemoScenario(
        id: "bypass",
        title: "Bypass on",
        subtitle: "Nothing in permittedFolders",
        json: DemoFixtures.machineWideBypass
    )

    public static let schemaDrift = DemoScenario(
        id: "drift",
        title: "Schema drift",
        subtitle: "The field got renamed",
        json: DemoFixtures.schemaDrift
    )

    public static let all: [DemoScenario] = [provisioned, homeDirectory, bypass, schemaDrift]
}
