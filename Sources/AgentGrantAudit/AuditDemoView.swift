#if canImport(SwiftUI)
import SwiftUI

/// The demo screen: pick a status document, see what the gate says about it.
public struct AuditDemoView: View {
    @State private var selection: String = DemoScenario.provisioned.id

    public init() {}

    private var scenario: DemoScenario {
        DemoScenario.all.first { $0.id == selection } ?? DemoScenario.provisioned
    }

    private var presentation: DemoPresentation {
        DemoEngine.present(scenario)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    picker
                    verdictCard
                    if let refusal = presentation.refusal {
                        refusalCard(refusal)
                    } else {
                        blastRadiusCard
                        findingsList
                    }
                }
                .padding(20)
            }
            .navigationTitle("Agent Grant Audit")
            .background(Color(white: 0.96).ignoresSafeArea())
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Scenario", selection: $selection) {
                ForEach(DemoScenario.all) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text(scenario.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(verdictColor)
                    .frame(width: 12, height: 12)
                Text(verdictLabel)
                    .font(.headline)
                Spacer()
                Text("exit \(presentation.report?.exitCode ?? 1)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(presentation.headline)
                .font(.system(.title3, design: .rounded).weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
    }

    private var verdictColor: Color {
        guard let report = presentation.report else { return .orange }
        switch report.worstSeverity {
        case .blocking: return .red
        case .warning: return .orange
        case .info: return .green
        }
    }

    private var verdictLabel: String {
        guard let report = presentation.report else { return "REFUSED" }
        return report.passes ? "PASS" : "BLOCKED"
    }

    private func refusalCard(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decoder refused the document")
                .font(.subheadline.weight(.semibold))
            Text(reason)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("Failing closed here is the whole point: a renamed field must not decode to a comfortable default.")
                .font(.footnote)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
    }

    private var blastRadiusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blast radius")
                .font(.subheadline.weight(.semibold))
            if presentation.bypassActive {
                Text("The grant list is empty, so grant-based reachability is 0. That number is not a safety signal here — the bypass admits every process on the machine, and leaves nothing to revoke.")
                    .font(.footnote)
            } else if let radius = presentation.blastRadius {
                if let widest = radius.widestGrant {
                    Text("Widest live grant: \(widest.scope.description)")
                        .font(.system(.footnote, design: .monospaced))
                }
                ForEach(radius.reachableProjects.prefix(6), id: \.self) { project in
                    Text(project.description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                if radius.projectCount > 6 {
                    Text("+ \(radius.projectCount - 6) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
    }

    private var findingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Findings")
                .font(.subheadline.weight(.semibold))
            ForEach(presentation.report?.findings ?? []) { finding in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(finding.severity.description.uppercased())
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(color(for: finding.severity).opacity(0.16)))
                            .foregroundStyle(color(for: finding.severity))
                        Text(finding.code.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(finding.detail)
                        .font(.footnote)
                    Text(finding.remediation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            }
        }
    }

    private func color(for severity: Severity) -> Color {
        switch severity {
        case .blocking: return .red
        case .warning: return .orange
        case .info: return .green
        }
    }
}
#endif
