import Foundation

/// Domain-level validation failures used by entities to protect business invariants.
enum DomainValidationError: LocalizedError, Equatable {
    case emptyValue(field: String)
    case negativeValue(field: String)
    case nonPositiveValue(field: String)
    case invalidSessionTransition
    case invalidCompletionDate

    var errorDescription: String? {
        switch self {
        case .emptyValue(let field):
            return "\(field) must not be empty."
        case .negativeValue(let field):
            return "\(field) must not be negative."
        case .nonPositiveValue(let field):
            return "\(field) must be greater than zero."
        case .invalidSessionTransition:
            return "The workout session can not transition to the requested state."
        case .invalidCompletionDate:
            return "The completion date must be later than the session start date."
        }
    }
}
