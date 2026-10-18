import Foundation
import Observation

// MARK: - Domain model (mirrors the Go Green approvals queue)

enum ApprovalCategory: String, CaseIterable, Identifiable {
    case confirmation = "Confirmation"
    case cleanerOffer = "Cleaner offer"
    case reminder = "Reminder"
    case customerText = "Customer text"
    case custom = "Custom"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .confirmation: return "checkmark.seal.fill"
        case .cleanerOffer: return "briefcase.fill"
        case .reminder: return "bell.fill"
        case .customerText: return "message.fill"
        case .custom: return "pencil.line"
        }
    }
}

/// The platform gate's verdict on a draft. `.blocked` is a hard stop —
/// approving stays disabled until the platform clears it. `.duplicate`
/// and `.needsInfo` are advisories: the item stays visible with its note
/// and Kevin can still make the call.
enum GateState: String, CaseIterable {
    case ready = "Ready"
    case blocked = "Blocked"
    case duplicate = "Duplicate"
    case needsInfo = "Needs info"

    var canApprove: Bool { self != .blocked }
}

struct ApprovalItem: Identifiable, Hashable {
    let id: String
    let category: ApprovalCategory
    let recipient: String
    let channel: String
    let body: String
    let context: String
    let createdAt: Date
    let gate: GateState
    let gateNote: String?
}

// MARK: - Service layer

protocol ApprovalService {
    func fetchPending() async throws -> [ApprovalItem]
    func decide(id: String, approved: Bool) async throws
}

enum ApprovalServiceError: Error {
    case notWiredYet
}

/// Demo data shaped exactly like the live approvals queue (same categories,
/// same gate states). Swapped for `APIApprovalService` once Kevin approves
/// the app's send-release authority and auth design — see README.
final class MockApprovalService: ApprovalService {
    func fetchPending() async throws -> [ApprovalItem] {
        try await Task.sleep(for: .milliseconds(350))
        return Self.samples
    }

    func decide(id: String, approved: Bool) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    static var samples: [ApprovalItem] {
        let now = Date()
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }
        return [
            ApprovalItem(
                id: "sample-001",
                category: .cleanerOffer,
                recipient: "Renee · Cleaner",
                channel: "Text",
                body: "New job for you: deep clean, Monday Oct 19, 9:00 AM in Sarasota. Address and entry details come after you accept. Reply YES to take it, NO to pass. 🌱🤖",
                context: "Deep clean · Mon Oct 19 · 9:00 AM · Sarasota",
                createdAt: hoursAgo(0.3),
                gate: .blocked,
                gateNote: "Outside cleaner texting hours (7 AM–9 PM ET) — the gate keeps sending paused."
            ),
            ApprovalItem(
                id: "sample-002",
                category: .cleanerOffer,
                recipient: "Dana · Cleaner",
                channel: "Text",
                body: "New job for you: regular clean, Friday Oct 23, 11:00 AM–1:00 PM in Bradenton. Address and entry details come after you accept. Reply YES to take it, NO to pass. 🌱🤖",
                context: "Regular clean · Fri Oct 23 · 11:00 AM · Bradenton",
                createdAt: hoursAgo(0.75),
                gate: .ready,
                gateNote: nil
            ),
            ApprovalItem(
                id: "sample-003",
                category: .confirmation,
                recipient: "Alicia R.",
                channel: "Text",
                body: "Hi Alicia! This is Go Green Organic Clean confirming your deep clean on Thursday, Oct 22 at 9:00 AM. We'll text when we're on the way. Reply here if anything changes! 🧼🌿Go Green Organic Clean Team 🌿🧼",
                context: "Deep clean · Thu Oct 22 · 9:00 AM · Sarasota",
                createdAt: hoursAgo(2),
                gate: .ready,
                gateNote: nil
            ),
            ApprovalItem(
                id: "sample-004",
                category: .reminder,
                recipient: "Marcus T.",
                channel: "Text",
                body: "Hi Marcus, friendly reminder of your cleaning tomorrow, Oct 19 at 10:00 AM. Please secure pets, and leave out any towels you'd like swapped. See you then! 🧼🌿Go Green Organic Clean Team 🌿🧼",
                context: "Regular clean · Mon Oct 19 · 10:00 AM · Lakewood Ranch",
                createdAt: hoursAgo(5),
                gate: .ready,
                gateNote: nil
            ),
            ApprovalItem(
                id: "sample-005",
                category: .customerText,
                recipient: "Bob H.",
                channel: "Email",
                body: "Hi Bob, happy to move your cleaning from Tuesday to Wednesday at the same time. Your cleaner has been notified and your booking is updated — no action needed from you.",
                context: "Reschedule reply · Tue → Wed",
                createdAt: hoursAgo(8),
                gate: .duplicate,
                gateNote: "A near-identical reply is already queued for this thread."
            ),
            ApprovalItem(
                id: "sample-006",
                category: .confirmation,
                recipient: "Sam K.",
                channel: "Text",
                body: "Hi Sam! Confirming your move-out clean on Saturday, Oct 24 at 1:00 PM. Keys and alarm details are on file. We'll send before/after photos when it's done. 🧼🌿Go Green Organic Clean Team 🌿🧼",
                context: "Move-out clean · Sat Oct 24 · 1:00 PM · Bradenton",
                createdAt: hoursAgo(12),
                gate: .ready,
                gateNote: nil
            ),
            ApprovalItem(
                id: "sample-007",
                category: .custom,
                recipient: "Priya S.",
                channel: "Text",
                body: "Hi Priya, following up on your cleaning estimate from last week — we'd love to get you on the schedule. Want me to hold a morning slot this week?",
                context: "Estimate follow-up · original estimate Oct 15",
                createdAt: hoursAgo(26),
                gate: .needsInfo,
                gateNote: "Home size isn't on file — the quoted estimate range may be off."
            ),
        ]
    }
}

/// Live platform client. Endpoints land with the approvals-API wiring;
/// until then the app runs on `MockApprovalService`.
struct APIApprovalService: ApprovalService {
    let baseURL = URL(string: "https://www.gogreenorganicclean.com")!

    func fetchPending() async throws -> [ApprovalItem] {
        throw ApprovalServiceError.notWiredYet
    }

    func decide(id: String, approved: Bool) async throws {
        throw ApprovalServiceError.notWiredYet
    }
}

// MARK: - Store

@MainActor
@Observable
final class TriageStore {
    var items: [ApprovalItem] = []
    var isLoading = false
    var errorMessage: String?
    var decidedCount = 0

    private let service: ApprovalService

    init(service: ApprovalService = MockApprovalService()) {
        self.service = service
    }

    var readyCount: Int { items.filter { $0.gate == .ready }.count }
    var attentionCount: Int { items.filter { $0.gate != .ready }.count }
    var oldestItem: ApprovalItem? { items.min { $0.createdAt < $1.createdAt } }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await service.fetchPending()
                .sorted { $0.createdAt < $1.createdAt }
        } catch {
            errorMessage = "Couldn't load the queue. Pull to try again."
        }
    }

    /// Optimistic decide: the card leaves the queue immediately; if the
    /// service call fails, the item is restored and an error surfaces.
    func decide(_ item: ApprovalItem, approved: Bool) async {
        items.removeAll { $0.id == item.id }
        decidedCount += 1
        do {
            try await service.decide(id: item.id, approved: approved)
        } catch {
            items.append(item)
            items.sort { $0.createdAt < $1.createdAt }
            decidedCount -= 1
            errorMessage = "That decision didn't save — the item is back in the queue."
        }
    }
}
