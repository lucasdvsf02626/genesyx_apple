import Foundation

/// A citable medical/scientific source shown next to a health claim (Guideline 1.4.1).
/// Loaded from `medical_sources.json` at launch by `MedicalSourceStore`.
struct MedicalSource: Identifiable, Codable, Hashable {
    let id: String            // stable key, e.g. "nhs-water"
    let title: String         // "Water, drinks and hydration"
    let organisation: String  // "NHS (UK)"
    let url: URL
}
