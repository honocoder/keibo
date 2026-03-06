import Foundation

/// The type of a budget category, which determines how it's displayed and handled.
enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case fixed    = "Fixe"
    case variable = "Variable"
    case savings  = "Épargne"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .fixed:    return "lock.fill"
        case .variable: return "cart.fill"
        case .savings:  return "banknote"
        }
    }

    var accentColorName: String {
        switch self {
        case .fixed:    return "TypeFixed"
        case .variable: return "TypeVariable"
        case .savings:  return "TypeSavings"
        }
    }
}
