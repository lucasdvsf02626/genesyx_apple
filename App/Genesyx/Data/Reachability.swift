import Foundation
import Network

/// Whether the device currently has a network route, and a hook that fires the moment one comes
/// back. The app had no notion of connectivity at all before this: the sync badge answered purely
/// from the owed-days set, so a row that was merely in flight was reported as "you're offline".
///
/// Two deliberate limits, both of which shape how this may be used:
///
/// 1. **A route is not the server.** `.satisfied` means packets have somewhere to go — not that
///    Supabase answered. Captive hotel wifi is `.satisfied` and useless. So this only ever chooses
///    *wording* and *when to retry*; it never gates a write. Every save still attempts its push and
///    still queues on failure, exactly as before.
/// 2. **The first update is asynchronous.** `NWPathMonitor` reports nothing until its queue runs, so
///    starting at `false` would flash "offline" on every cold launch. It starts optimistic; being
///    briefly wrong in the direction of silence is better than crying offline at a user who isn't.
@MainActor
final class Reachability: ObservableObject {

    /// Optimistic until the monitor speaks. See note 2 above.
    @Published private(set) var isOnline = true

    /// Called when the path goes from unsatisfied to satisfied. `AppContainer` uses it to drain the
    /// owed queues, so a reconnect clears the backlog then and there rather than waiting for the
    /// next foreground — which, for a phone that never leaves her hand, may be hours away.
    var onReconnect: (@MainActor () async -> Void)?

    private let monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.genesyx.reachability")

    /// `monitoring: false` builds an inert instance for tests and previews, where a real monitor
    /// would report the *host's* connectivity and make the assertions depend on the network.
    init(monitoring: Bool = true) {
        guard monitoring else {
            self.monitor = nil
            return
        }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.apply(online: online) }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor?.cancel() }

    /// The test seam for note 1's "never gates a write" contract: drives the same code path the
    /// monitor drives, without a network.
    func simulate(online: Bool) { apply(online: online) }

    private func apply(online: Bool) {
        let reconnected = online && !isOnline
        guard online != isOnline else { return }
        isOnline = online
        if reconnected, let onReconnect {
            Task { await onReconnect() }
        }
    }
}
