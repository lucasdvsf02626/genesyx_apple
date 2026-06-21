import Foundation

/// Shared email validation (mirrors the web zod `string().email()` / Android `isValidEmail`).
enum EmailValidator {
    static func isValid(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces)
            .range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}
