import Foundation

/// Loads the bundled `medical_sources.json` once and vends sources by id.
/// Uses the bundle that owns this class so it resolves correctly under unit tests too.
final class MedicalSourceStore {
    static let shared = MedicalSourceStore()

    private(set) var sources: [MedicalSource] = []

    private init() {
        guard let url = Bundle(for: MedicalSourceStore.self).url(forResource: "medical_sources", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([MedicalSource].self, from: data)
        else {
            assertionFailure("medical_sources.json missing or malformed")
            return
        }
        sources = decoded
    }

    func source(_ id: String) -> MedicalSource? {
        sources.first { $0.id == id }
    }
}
