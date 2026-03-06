import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    /// SF Symbol name used as the category icon.
    var icon: String
    var type: CategoryType
    /// Monthly budget target for this category (in the user's currency).
    var targetAmount: Double
    /// Display order within its type section.
    var sortOrder: Int
    /// Starting balance for savings accounts (e.g. money already on the account before using the app).
    var initialBalance: Double

    /// All transactions linked to this category.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]

    init(
        name: String,
        icon: String,
        type: CategoryType,
        targetAmount: Double,
        sortOrder: Int = 0,
        initialBalance: Double = 0
    ) {
        self.id             = UUID()
        self.name           = name
        self.icon           = icon
        self.type           = type
        self.targetAmount   = targetAmount
        self.sortOrder      = sortOrder
        self.initialBalance = initialBalance
        self.transactions   = []
    }
}

extension Category: Identifiable {}
