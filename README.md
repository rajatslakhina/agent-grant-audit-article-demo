# AgentGrantAudit

A small Swift package that decodes the JSON emitted by `xcrun mcp-server status --format json`, grades it against a **policy you commit to your repository**, and produces a verdict plus an exit code a build phase can act on.

It exists to make one argument concrete: when a coding agent is handed the Xcode toolchain, the grant that admits it is a security artefact — and right now that artefact lives in a dialog box nobody reviews.

---

## The finding the package is built around

An empty `permittedFolders` array is the most dangerous state this configuration can be in.

Two very different machines produce it. One has never trusted anything. The other was enabled with `--unsafe-always-allow-all-agents`, which trusts every process on the box — and because the bypass is not itself a grant, it **leaves nothing in `permittedFolders` to revoke**. Read only the folder list and both machines look identically, reassuringly clean.

```swift
if status.allowsAllAgents {
    findings.append(
        Finding(
            code: .machineWideBypassEnabled,
            severity: .blocking,
            detail: """
                The machine-wide bypass is on. Every process on this Mac is trusted, \
                and because the bypass is not itself a grant, the grant list stays \
                empty — so an audit that only reads grants sees the safest-looking \
                configuration this machine can produce.
                """,
            remediation: "Disable and re-enable the service, or clear its permissions, then re-grant per repository."
        )
    )
}
```

## Path containment is component-wise, not prefix-wise

The obvious implementation of "is this grant inside an approved root" is `hasPrefix`, and it is wrong:

```swift
XCTAssertTrue("/Users/r/Devious".hasPrefix("/Users/r/Dev"))  // the naive check says yes
XCTAssertFalse(PathScope("/Users/r/Dev")!.contains(PathScope("/Users/r/Devious")!))
```

`PathScope` normalises to components, resolves `.` and `..` lexically, and **refuses** relative paths and paths that escape the root rather than repairing them. A policy that silently reinterprets an input it did not understand is worse than one that declines it.

## The decoder fails closed on purpose

`StatusDecoder` requires every field the verdict depends on. A document missing `unsafeAlwaysAllowAllAgents` is refused, not defaulted:

```swift
XCTAssertThrowsError(try StatusDecoder.decode(Data(DemoFixtures.schemaDrift.utf8))) { error in
    XCTAssertEqual(
        error as? StatusDecodingError,
        .missingSecurityRelevantField("unsafeAlwaysAllowAllAgents")
    )
}
```

`trust` gets the same treatment. It is a tagged union whose only current variant is `signed`; an agent carrying a variant this build has never seen is refused rather than decoded as *trusted, details unknown*.

That strictness has a real cost — the gate goes red the first time the vendor renames a key, on a machine that was never misconfigured. It is still the better failure. The alternative is a renamed key decoding to `false`, the bypass going unseen, and the gate reporting green, which is the failure that does damage because nothing about it looks like one.

## Blast radius

`BlastRadius` answers the question the dialog does not: the prompt asks about a *folder*, the consequence is a *project count*.

| Grant | Reachable projects (of 12) |
|---|---|
| `~/Developer/checkout-ios`, expires in 12h | 2 |
| `~/Developer`, permanent | 9 |
| bypass on, zero folders listed | all 12 |

---

## What's in the box

| Type | Job |
|---|---|
| `PathScope` | Component-wise absolute-path containment |
| `GrantExpiry` | `.never` / `.at(Date)` — permanent is a *kind*, not a long duration |
| `StatusDecoder` | Strict, fail-closed decoding of the status document |
| `TrustPolicy` | Approved team identifiers, approved grant roots, lifetime ceiling |
| `GrantAuditor` | Findings with severity and remediation; worst severity wins |
| `BlastRadius` | Grants × real project paths → what is actually reachable |
| `DemoEngine` / `AuditDemoView` | Four scenarios, rendered |

## Using it as a build gate

The package deliberately ships no executable target, so the process glue lives on your side. It is about this much:

```swift
let status = Process()
status.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
status.arguments = ["mcp-server", "status", "--format", "json"]

let pipe = Pipe()
status.standardOutput = pipe
try status.run()

let decoded = try StatusDecoder.decode(pipe.fileHandleForReading.readDataToEndOfFile())

let policy = TrustPolicy(
    approvedTeamIdentifiers: ["Q6L2SF6YDW"],
    approvedGrantRoots: ["/Users/you/Developer/checkout-ios"].compactMap(PathScope.init)
)

let report = GrantAuditor(policy: policy).audit(decoded, now: Date())
report.findings.forEach { print("[\($0.severity)] \($0.detail) — \($0.remediation)") }
exit(report.exitCode)
```

That snippet is documentation, not a shipped artefact: it is not compiled by this package and not covered by the test suite.

## How to run it

```
git clone https://github.com/rajatslakhina/agent-grant-audit-article-demo
cd agent-grant-audit-article-demo
swift test                       # library + tests, no Xcode needed
open Demo/Demo.xcodeproj         # pick any iOS Simulator, then Build & Run
```

`Demo/Demo.xcodeproj` consumes the package through an `XCLocalSwiftPackageReference` pointing at `..`, so there is nothing else to fetch. `Package.swift` declares one library target and one test target and **no executable target of any kind** — the runnable app lives only in the `.xcodeproj`.

---

## Verification status

Stated plainly, because a demo repo that overstates its own testing is exactly the problem this package is about.

**Verified, on Swift 6.0.3 (aarch64 Linux), from a clean `.build`:**

- `swift build --build-tests -Xswiftc -warnings-as-errors` — **0 warnings**
- `swift test` — **50 tests, 0 failures**
- **0** force-unwraps, `try!`, `as!` or `fatalError` anywhere in `Sources/`
- `Demo/Demo.xcodeproj/project.pbxproj` — 30/30 braces, 24/24 parens balanced; all 20 object IDs defined and referenced, zero dangling refs
- `Demo.xcscheme` — valid XML, blueprint identifier matches the target
- `Demo/DemoApp.swift` and `AuditDemoView.swift` — `swiftc -parse` clean

**Not verified:**

- **The app has never been launched.** No Simulator run happened during the run that produced this repo. Computer-use access to Xcode and Simulator was requested, and the request came back refused: *"Computer-use access can't be approved during a scheduled run."* There is no `Demo/Screenshots/` directory, and no screenshot in this README, because neither exists.
- **`AuditDemoView` and `DemoApp.swift` have never been compiled by anything.** SwiftUI does not exist on Linux, so the view sits behind `#if canImport(SwiftUI)` and the Linux build skips it. They parse; they have not been type-checked.
- The core logic *is* fully exercised — `DemoEngine` computes everything the view renders and is asserted on directly in `DemoEngineTests`, so the numbers on that screen are tested even though the screen is not.

## A note on the status schema

Apple documents neither the `status --format json` schema nor the on-disk permissions file, and the CLI surface is explicitly beta. The shape decoded here — `running`, and a `permission` object holding `enabled`, `unsafeAlwaysAllowAllAgents`, `permittedAgents[].trust.signed.{signingIdentifier, teamIdentifier}` and `permittedFolders[].subtreeRoot` — follows the output published in [Artem Novichkov's write-up of Xcode 27 beta 5's headless MCP server](https://artemnovichkov.com/blog/headless-xcode-from-prompt-to-simulator-with-mcp) (13 August 2026). Treat it as a moving target. That is the argument for pinning your expectations in code you own and failing closed when they stop matching — not a reason to skip checking.

## Licence

MIT.
