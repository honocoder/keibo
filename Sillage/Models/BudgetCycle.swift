import Foundation
import SwiftData

/// Represents one rolling budget period.
/// Created automatically by BudgetManager when a new cycle begins.
@Model
final class BudgetCycle {
    var id: UUID
    var startDate: Date
    var endDate: Date
    /// Base income declared by the user for this cycle.
    var totalIncome: Double
    /// Surplus carried over automatically from the previous cycle.
    var rolloverAmount: Double
    /// Additional income added during the cycle (freelance, gifts, etc.).
    var extraIncome: Double

    /// Effective income = totalIncome + rolloverAmount + extraIncome
    var effectiveIncome: Double { totalIncome + rolloverAmount + extraIncome }

    init(
        startDate: Date,
        endDate: Date,
        totalIncome: Double = 0,
        rolloverAmount: Double = 0,
        extraIncome: Double = 0
    ) {
        self.id             = UUID()
        self.startDate      = startDate
        self.endDate        = endDate
        self.totalIncome    = totalIncome
        self.rolloverAmount = rolloverAmount
        self.extraIncome    = extraIncome
    }
}

extension BudgetCycle: Identifiable {}
