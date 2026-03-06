import Foundation
import SwiftData

/// Singleton configuration for the user. Only one instance should exist in the store.
@Model
final class UserConfig {
    /// Day of the month on which the budget cycle starts (1–31).
    var startDayOfMonth: Int
    /// Whether Face ID / Touch ID is required to open the app.
    var isBiometricAuthEnabled: Bool
    /// ISO-4217 currency code shown throughout the app.
    var currencyCode: String
    /// Monthly income amount entered by the user.
    var monthlyIncome: Double

    init(
        startDayOfMonth: Int = 28,
        isBiometricAuthEnabled: Bool = false,
        currencyCode: String = "EUR",
        monthlyIncome: Double = 0
    ) {
        self.startDayOfMonth     = startDayOfMonth
        self.isBiometricAuthEnabled = isBiometricAuthEnabled
        self.currencyCode        = currencyCode
        self.monthlyIncome       = monthlyIncome
    }
}
