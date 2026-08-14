import Foundation

/// When she takes a supplement.
///
/// ⚠️ The raw values are a **cross-platform contract**, not labels. They are the four values
/// `user_supplements.time_of_day` will accept —
/// `check (time_of_day is null or time_of_day in ('morning','afternoon','evening','anytime'))` —
/// and Android's `SupplementTime.wire` is the same four strings. Rename one after a client ships
/// and every row already written becomes unreadable on the other phone.
public enum SupplementTime: String, Codable, CaseIterable, Sendable {
    case morning, afternoon, evening, anytime

    /// What she reads. Matches Android's `SupplementTime.label` so the same supplement is described
    /// the same way on both phones.
    public var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .anytime: return "Anytime"
        }
    }

    /// Read a stored or server value. Deliberately forgiving of case and surrounding space, because
    /// this also has to read what iOS users typed into the free-text box this replaced — "Evening",
    /// " morning " and "Anytime" are all recoverable, and anything else is simply unset rather than
    /// a decode failure.
    public static func parse(_ raw: String?) -> SupplementTime? {
        guard let raw else { return nil }
        return SupplementTime(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// A supplement she added herself (distinct from the fixed Genesyx plan).
///
/// Mirrors Supabase `user_supplements`, live since 13 Aug 2026 with owner-only RLS, and Android's
/// `UserSupplement`. The two clients now share one table, so the bounds below are not house style —
/// they are what the server will accept.
public struct CustomSupplement: Identifiable, Codable, Equatable, Sendable {
    /// UserDefaults key for the locally-stored list (shared by the UI binding and the sign-out wipe,
    /// so the two can never drift apart).
    public static let storageKey = "custom_supplements"

    /// Server contract: `name` is `check (char_length(btrim(name)) between 1 and 60)`. Enforced here
    /// as well as in the field, because a name that gets past the UI is rejected by the database and
    /// then sits in the pending queue forever, retrying a write that can never succeed.
    public static let nameMaxLength = 60

    public let id: String
    public var name: String
    public var dose: String
    public var timeOfDay: SupplementTime?

    public init(id: String = UUID().uuidString, name: String, dose: String,
                timeOfDay: SupplementTime? = nil) {
        self.id = id
        self.name = name
        self.dose = dose
        self.timeOfDay = timeOfDay
    }

    /// Trimmed name, 1–60 characters. Dose stays optional free text; the column is unbounded.
    public var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= Self.nameMaxLength
    }

    // The stored key stays `time` — this list has been persisted under that name since the feature
    // shipped, and renaming it would orphan every supplement already on a phone.
    private enum CodingKeys: String, CodingKey { case id, name, dose, time }

    /// Hand-written because the stored `time` used to be free text and a strict decode of the whole
    /// array is all-or-nothing: one unrecognisable string and `decodeList` returns `[]`, losing not
    /// the time but **every supplement she ever added**. Read leniently, so an unrecognised time
    /// costs only itself.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        dose = try c.decodeIfPresent(String.self, forKey: .dose) ?? ""
        timeOfDay = SupplementTime.parse(try? c.decodeIfPresent(String.self, forKey: .time))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dose, forKey: .dose)
        try c.encodeIfPresent(timeOfDay?.rawValue, forKey: .time)
    }

    /// Decode a stored JSON array (empty on any failure — never crashes the UI).
    public static func decodeList(_ json: String) -> [CustomSupplement] {
        guard let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([CustomSupplement].self, from: data) else { return [] }
        return list
    }

    /// Encode a list back to a JSON string for local storage.
    public static func encodeList(_ list: [CustomSupplement]) -> String {
        guard let data = try? JSONEncoder().encode(list), let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }
}
