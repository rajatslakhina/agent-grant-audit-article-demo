import Foundation

/// Fixtures shared by the demo app and the test suite, so the screenshots and
/// the assertions are grading the same bytes.
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
      "enabled": true,
      "allowAllAgents": false,
      "agents": [
        { "signingIdentifier": "com.anthropic.claude-code", "teamIdentifier": "Q6L2SF6YDW" }
      ],
      "folderGrants": [
        { "path": "/Users/rajat/Developer/checkout-ios", "reach": "recursive", "expiresAt": 1787043200 }
      ]
    }
    """

    /// One click on the parent folder of everything. Recursive, permanent.
    public static let homeDirectoryGrant = """
    {
      "enabled": true,
      "allowAllAgents": false,
      "agents": [
        { "signingIdentifier": "com.anthropic.claude-code", "teamIdentifier": "Q6L2SF6YDW" },
        { "signingIdentifier": "com.example.unknown-agent", "teamIdentifier": "ZZ99TESTTEAM" }
      ],
      "folderGrants": [
        { "path": "/Users/rajat/Developer", "reach": "recursive" }
      ]
    }
    """

    /// The bypass. Note what is *not* here: any grant to revoke.
    public static let machineWideBypass = """
    {
      "enabled": true,
      "allowAllAgents": true,
      "agents": [],
      "folderGrants": []
    }
    """

    /// A document from a toolchain that renamed the field the verdict depends on.
    public static let schemaDrift = """
    {
      "enabled": true,
      "unsafeAllowAllAgents": false,
      "agents": [
        { "signingIdentifier": "com.anthropic.claude-code", "teamIdentifier": "Q6L2SF6YDW" }
      ],
      "folderGrants": []
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
        subtitle: "Recursive grant on ~/Developer",
        json: DemoFixtures.homeDirectoryGrant
    )

    public static let bypass = DemoScenario(
        id: "bypass",
        title: "Bypass on",
        subtitle: "Nothing in the grant list",
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
