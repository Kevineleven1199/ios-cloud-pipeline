import SwiftUI

struct ContentView: View {
    @State private var store = TriageStore()
    @State private var filter: ApprovalCategory?

    private var visibleItems: [ApprovalItem] {
        guard let filter else { return store.items }
        return store.items.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                filterBar
                queue
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GG Triage")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ApprovalItem.self) { item in
                ApprovalDetailView(item: item, store: store)
            }
            .task { await store.load() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                Text("Go Green Organic Clean")
                    .font(.headline)
                Spacer()
                Text("DEMO DATA")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.25), in: Capsule())
            }
            if store.items.isEmpty && !store.isLoading {
                Text("Queue clear — nothing waiting on you.")
                    .font(.title3.weight(.semibold))
            } else {
                Text("\(store.items.count) waiting · \(store.readyCount) ready to send")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    if let oldest = store.oldestItem {
                        Label("Oldest \(Self.relative(oldest.createdAt))", systemImage: "clock")
                    }
                    if store.attentionCount > 0 {
                        Label("\(store.attentionCount) need attention", systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .font(.caption.weight(.medium))
                .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.46, blue: 0.23),
                         Color(red: 0.03, green: 0.30, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: Filter chips

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", category: nil)
                ForEach(ApprovalCategory.allCases) { category in
                    chip(title: category.rawValue, category: category)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func chip(title: String, category: ApprovalCategory?) -> some View {
        let selected = filter == category
        return Button(title) { filter = category }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selected ? Color(red: 0.06, green: 0.46, blue: 0.23) : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .foregroundStyle(selected ? .white : .primary)
            .buttonStyle(.plain)
    }

    // MARK: Queue

    private var queue: some View {
        Group {
            if store.isLoading && store.items.isEmpty {
                ProgressView("Loading the queue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                ContentUnavailableView(
                    "Queue clear",
                    systemImage: "checkmark.circle.fill",
                    description: Text("Nothing waiting on you. New drafts land here the moment they're ready for your call.")
                )
            } else {
                List {
                    if let error = store.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .listRowBackground(Color.red.opacity(0.08))
                    }
                    ForEach(visibleItems) { item in
                        NavigationLink(value: item) {
                            ApprovalCard(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: item.gate.canApprove) {
                            if item.gate.canApprove {
                                Button {
                                    Task { await store.decide(item, approved: true) }
                                } label: {
                                    Label("Approve", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await store.decide(item, approved: false) }
                            } label: {
                                Label("Deny", systemImage: "xmark")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await store.load() }
            }
        }
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Queue card

struct ApprovalCard: View {
    let item: ApprovalItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(item.category.rawValue, systemImage: item.category.symbol)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
                Text(item.channel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                GateBadge(gate: item.gate)
            }
            Text(item.recipient)
                .font(.headline)
            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("\(item.context) · \(ContentView.relative(item.createdAt))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct GateBadge: View {
    let gate: GateState

    var body: some View {
        Text(gate.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch gate {
        case .ready: return .green
        case .blocked: return .red
        case .duplicate: return .orange
        case .needsInfo: return .purple
        }
    }
}

#Preview {
    ContentView()
}
