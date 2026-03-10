import Foundation
import SwiftData

public enum BillingFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    public var id: String { rawValue }
}

@Model
final class Subscription {
    var id: UUID
    var name: String
    var amount: Double
    var frequency: BillingFrequency
    var nextBillingDate: Date
    var note: String
    // Optional link to a budgeting category if applicable
    var category: Category?
    // Whether the subscription is currently active
    var isActive: Bool

    init(
        name: String,
        amount: Double,
        frequency: BillingFrequency = .monthly,
        nextBillingDate: Date = .now,
        note: String = "",
        category: Category? = nil,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.nextBillingDate = nextBillingDate
        self.note = note
        self.category = category
        self.isActive = isActive
    }
}

extension Subscription: Identifiable {}
