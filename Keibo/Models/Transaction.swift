import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var amount: Double
    var date: Date
    var note: String
    /// The category this transaction is assigned to (nil = unassigned / income).
    var category: Category?

    init(
        amount: Double,
        date: Date = .now,
        note: String = "",
        category: Category? = nil
    ) {
        self.id       = UUID()
        self.amount   = amount
        self.date     = date
        self.note     = note
        self.category = category
    }
}

extension Transaction: Identifiable {}
