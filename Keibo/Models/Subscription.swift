import Foundation
import SwiftData

// MARK: - Billing Cycle

enum BillingCycle: String, Codable, CaseIterable {
    case weekly  = "weekly"
    case monthly = "monthly"
    case yearly  = "yearly"

    var displayName: String {
        switch self {
        case .weekly:  return "Hebdomadaire"
        case .monthly: return "Mensuel"
        case .yearly:  return "Annuel"
        }
    }

    /// Converts the given amount to its monthly equivalent.
    func monthlyAmount(for amount: Double) -> Double {
        switch self {
        case .weekly:  return amount * 52 / 12
        case .monthly: return amount
        case .yearly:  return amount / 12
        }
    }
}

// MARK: - Subscription Category

enum SubscriptionCategory: String, Codable, CaseIterable {
    case videoStreaming = "videoStreaming"
    case musicStreaming = "musicStreaming"
    case gaming        = "gaming"
    case software      = "software"
    case cloudStorage  = "cloudStorage"
    case healthFitness = "healthFitness"
    case newsMedia     = "newsMedia"
    case other         = "other"

    var displayName: String {
        switch self {
        case .videoStreaming: return "Streaming vidéo"
        case .musicStreaming: return "Streaming musique"
        case .gaming:         return "Jeux vidéo"
        case .software:       return "Logiciels"
        case .cloudStorage:   return "Cloud & stockage"
        case .healthFitness:  return "Sport & santé"
        case .newsMedia:      return "News & presse"
        case .other:          return "Autre"
        }
    }

    var icon: String {
        switch self {
        case .videoStreaming: return "tv.fill"
        case .musicStreaming: return "music.note"
        case .gaming:         return "gamecontroller.fill"
        case .software:       return "laptopcomputer"
        case .cloudStorage:   return "icloud.fill"
        case .healthFitness:  return "heart.fill"
        case .newsMedia:      return "newspaper.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Subscription Model

@Model
final class Subscription {
    var name:         String
    var amount:       Double
    var billingCycle: BillingCycle
    var category:     SubscriptionCategory
    var icon:         String
    var createdAt:    Date

    init(
        name:         String,
        amount:       Double,
        billingCycle: BillingCycle = .monthly,
        category:     SubscriptionCategory = .other,
        icon:         String = "creditcard.fill"
    ) {
        self.name         = name
        self.amount       = amount
        self.billingCycle = billingCycle
        self.category     = category
        self.icon         = icon
        self.createdAt    = Date()
    }

    var monthlyAmount: Double { billingCycle.monthlyAmount(for: amount) }
    var annualAmount:  Double { monthlyAmount * 12 }
}
