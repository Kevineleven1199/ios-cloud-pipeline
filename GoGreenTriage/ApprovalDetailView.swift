import SwiftUI

/// One draft, one decision. Approve/deny only — no editing, by design:
/// drafts are written by the office; Kevin's job is the call.
struct ApprovalDetailView: View {
    let item: ApprovalItem
    let store: TriageStore

    @Environment(\.dismiss) private var dismiss
    @State private var deciding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                contextCard
                messageCard
                if item.gate != .ready {
                    gateWarning
                }
                Spacer(minLength: 8)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { decisionBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(item.category.rawValue, systemImage: item.category.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
                Spacer()
                GateBadge(gate: item.gate)
            }
            Text(item.recipient)
                .font(.title2.bold())
            Text("\(item.channel) · waiting \(ContentView.relative(item.createdAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var contextCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
            Text(item.context)
                .font(.subheadline.weight(.medium))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MESSAGE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(item.body)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var gateWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Gate: \(item.gate.rawValue)")
                    .font(.subheadline.bold())
                if let note = item.gateNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(item.gate == .blocked
                     ? "Approving is paused until the platform clears this. You can still deny it."
                     : "You can approve it, but check the note first — or deny and let the office fix it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private var decisionBar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                decide(approved: false)
            } label: {
                Label("Deny", systemImage: "xmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(deciding)

            Button {
                decide(approved: true)
            } label: {
                Label("Approve", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.06, green: 0.46, blue: 0.23))
            .disabled(deciding || !item.gate.canApprove)
        }
        .padding()
        .background(.bar)
    }

    private func decide(approved: Bool) {
        deciding = true
        Task {
            await store.decide(item, approved: approved)
            dismiss()
        }
    }
}
