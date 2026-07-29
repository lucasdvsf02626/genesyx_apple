import Foundation

/// A user-added supplement (distinct from the fixed Genesyx plan). Fields mirror the client brief:
/// name, dose, time.
///
/// ⚠️ REMOTE PERSISTENCE PENDING: the brief requires these to persist to Supabase with a schema
/// *identical to the Android implementation*. That schema is not yet confirmed here, so this type is
/// currently persisted LOCALLY only (JSON in UserDefaults). Do not add a Supabase table / DTO until
/// the shared Android schema (table name + column names/types) is confirmed — flag, don't apply.
public struct CustomSupplement: Identifiable, Codable, Equatable, Sendable {
    /// UserDefaults key for the locally-stored list (shared by the @AppStorage UI binding and the
    /// sign-out wipe, so the two can never drift apart).
    public static let storageKey = "custom_supplements"

    public let id: String
    public var name: String
    public var dose: String
    public var time: String

    public init(id: String = UUID().uuidString, name: String, dose: String, time: String) {
        self.id = id
        self.name = name
        self.dose = dose
        self.time = time
    }

    /// Trimmed, non-empty name is the only hard requirement; dose/time are optional free text.
    public var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
