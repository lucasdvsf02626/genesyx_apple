import Foundation
import GenesyxCore

/// Asked by every repository that stores special-category data, immediately before it writes.
///
/// The gate lives at the repository rather than on the entry screens because that is the only place
/// it can be complete. There are ten call sites in the UI that reach a health write, across seven
/// files, and a new one is a screen away — "she cannot get to a control that writes" is a claim that
/// has to be re-proved every time the UI changes, while "the write itself refuses" does not.
///
/// Defaults to permitting, and is wired to the real answer once, in `AppContainer`. That default is
/// fail-open, which is the wrong direction for a lawful-basis check and is a deliberate, narrow
/// trade: every test and preview builds repositories directly, and a fail-closed default would make
/// them silently store nothing rather than fail, which is a far easier mistake to ship than a
/// missing line in one composition root.
typealias HealthDataCollectionGate = @MainActor () -> Bool

/// Her UK GDPR Article 9 consent trail, on-device and mirrored to `consent_events`.
///
/// The odd one out among the repositories, in three ways that all follow from it being an audit
/// trail rather than a cache:
///
/// 1. **Nothing is ever edited or deleted.** There is no upsert and no tombstone. Withdrawing is
///    appending a `.withdrawn` row, and re-granting is appending another `.granted` row. Article
///    7(1) puts the burden of proving consent on the controller, and a record the subject can
///    rewrite proves nothing.
/// 2. **A merge is a union, not a resolution.** Events are immutable and carry a device-generated
///    id, so two devices can never disagree about one — only hold different subsets. There is no
///    local-wins rule here because there is no conflict to win.
/// 3. **The consent moment is stamped on the device.** Onboarding runs before sign-up, so the row
///    reaches the server minutes or hours after she agreed. `occurred_at` is sent, not defaulted,
///    or the trail would record when the phone next had a session — see `ConsentEventRow`.
@MainActor
final class ConsentRepository: ObservableObject {

    /// Her whole consent history, oldest first. Read-only from outside: `record` is the one way in,
    /// because it is also what owes the event to the server.
    @Published private(set) var events: [ConsentEvent] = []

    /// Whether Genesyx may currently collect health data from her. The one question the rest of the
    /// app asks. False until she has been asked and said yes, so a device that has never reached the
    /// consent screen — or one that cannot decode its own stored trail — collects nothing.
    var isActive: Bool { ConsentLogic.isActive(events) }

    /// The event that decides `isActive`, for the Profile screen to show her what she agreed to and
    /// when. Nil before she has ever been asked.
    var current: ConsentEvent? { ConsentLogic.latest(events) }

    private let store: LocalStore
    private let backend: ConsentBackend?
    private let eventsKey = "consent_events"
    private let pendingKey = "consent_pending"

    /// Ids of events the server has not acknowledged. Held separately from the events themselves so
    /// that an event stays byte-identical from the moment she agrees to the moment it lands — a
    /// "synced" flag inside the record would mean mutating the thing whose immutability is the
    /// entire point.
    private var pendingIds: Set<String> {
        didSet { store.save(Array(pendingIds), forKey: pendingKey) }
    }

    init(store: LocalStore, backend: ConsentBackend? = nil) {
        self.store = store
        self.backend = backend
        self.events = store.load([ConsentEvent].self, forKey: eventsKey) ?? []
        self.pendingIds = Set(store.load([String].self, forKey: pendingKey) ?? [])
    }

    /// Record that she granted consent to the wording currently in force.
    ///
    /// Always appends, even if `isActive` is already true. A re-grant against a bumped version is a
    /// separate fact from the original grant, and collapsing the two would lose which wording she
    /// actually saw.
    func grant() { record(.granted) }

    /// Record a withdrawal (Article 7(3)).
    ///
    /// Deliberately does not delete anything. Withdrawal stops future processing; erasing what was
    /// already collected is Article 17 and a different control, on the same Profile screen. Silently
    /// conflating them would destroy her data on a tap that did not ask to.
    func withdraw() { record(.withdrawn) }

    private func record(_ action: ConsentAction) {
        let event = ConsentEvent(version: ConsentPolicy.currentVersion, action: action, occurredAt: Date())
        events.append(event)
        pendingIds.insert(event.id)
        persist()
        guard backend != nil else { return }
        Task { await drainPending() }
    }

    /// Push what is owed, then pull. Pull second so a device that has been offline contributes its
    /// events before it learns about anyone else's, and so the union it ends up with is complete.
    func refresh() async {
        guard let backend else { return }
        await drainPending()

        let remote: [ConsentEvent]
        do { remote = try await backend.list() } catch { return }

        // Union by id. Anything still pending is kept whatever the server returned: an event the
        // push has not yet placed is not absent from her history, only from theirs.
        var byId = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for event in remote where byId[event.id] == nil { byId[event.id] = event }
        events = byId.values.sorted { $0.occurredAt < $1.occurredAt }
        persist()
    }

    /// Retry the appends the server never received, oldest first. Same halt/step-over rule as the
    /// other queues: a connection failure is the same answer for everything behind it, a rejection
    /// is about one row.
    func drainPending() async {
        guard let backend, !pendingIds.isEmpty else { return }
        for event in events where pendingIds.contains(event.id) {
            do {
                try await backend.append(event)
                pendingIds.remove(event.id)
            } catch {
                if SyncError.shouldHaltDrain(error) { break }
                continue
            }
        }
    }

    /// Wipe the trail from this device on sign-out. Her consent history is as personal as a log, and
    /// leaving it behind would tell the next user on this phone that permission had already been
    /// given — by someone else. The server keeps her copy and it returns on her next refresh.
    ///
    /// Drops anything still owed for the same reason `clearOwedProfileWrite` does: the flag outlives
    /// the session that owed it, so a retained queue would write her consent under the next
    /// account's user id.
    func clearLocalState() {
        events = []
        pendingIds = []
        store.remove(forKey: eventsKey)
        store.remove(forKey: pendingKey)
    }

    private func persist() { store.save(events, forKey: eventsKey) }
}
