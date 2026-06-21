import Foundation

/// Lightweight on-device store backed by `UserDefaults` + Codable JSON. This is the iOS
/// equivalent of the Android DataStore the repositories persist to (local-only v1).
/// Keys are namespaced under `genesyx.` to avoid collisions.
final class LocalStore {

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ k: String) -> String { "genesyx.\(k)" }

    func load<T: Decodable>(_ type: T.Type, forKey k: String) -> T? {
        guard let data = defaults.data(forKey: key(k)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, forKey k: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key(k))
    }

    func remove(forKey k: String) { defaults.removeObject(forKey: key(k)) }

    // Primitive helpers (avoid JSON-fragment encoding pitfalls)
    func string(forKey k: String) -> String? { defaults.string(forKey: key(k)) }
    func setString(_ value: String, forKey k: String) { defaults.set(value, forKey: key(k)) }
    func bool(forKey k: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: key(k)) == nil ? fallback : defaults.bool(forKey: key(k))
    }
    func setBool(_ value: Bool, forKey k: String) { defaults.set(value, forKey: key(k)) }
}
