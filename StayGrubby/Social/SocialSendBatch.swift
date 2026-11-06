import Foundation
import Observation

/// One deliberate sheet operation, one stable idempotency key per recipient.
/// Unknown network outcomes retry the same key; confirmed deliveries never resend.
@MainActor @Observable final class SocialSendBatch {
    private(set) var selected: [UUID: SocialPerson] = [:]
    private(set) var delivered = Set<UUID>()
    private(set) var failed = Set<UUID>()
    private(set) var busy = false
    private var origins: [UUID: UUID] = [:]
    private var generation = UUID()
    var pending: [UUID] { selected.keys.filter { !delivered.contains($0) }.sorted { $0.uuidString < $1.uuidString } }
    var complete: Bool { !selected.isEmpty && pending.isEmpty }

    func toggle(_ person: SocialPerson) {
        guard !busy, person.relationship == .friends, !delivered.contains(person.id) else { return }
        if selected.removeValue(forKey: person.id) == nil { selected[person.id] = person }
        failed.remove(person.id)
    }
    func suspend() {
        generation = UUID(); busy = false; selected = [:]; failed = []
        // Retain keys/receipts until sheet destruction: a backgrounded request
        // may have reached the server even if the client never saw its receipt.
    }
    func send(content: SocialSendContent, request: SocialRequest) async {
        guard !busy else { return }
        let recipients = pending, token = generation
        guard !recipients.isEmpty else { return }
        busy = true; failed = []
        defer { if generation == token { busy = false } }
        for peer in recipients {
            guard !Task.isCancelled, token == generation else { return }
            if origins[peer] == nil { origins[peer] = UUID() }
            do {
                struct Receipt: Decodable { let sent: Bool }
                // Server rechecks current access, relationship and block state.
                let receipt = try JSONDecoder().decode(Receipt.self, from: await request("social_send", "send", content.payload(peer: peer, origin: origins[peer])))
                guard !Task.isCancelled, token == generation else { return }
                if receipt.sent { delivered.insert(peer) } else { failed.insert(peer) }
            } catch is CancellationError { return }
            catch { if generation == token { failed.insert(peer) } }
        }
    }
}
