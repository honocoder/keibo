import Foundation
import LocalAuthentication
import Observation

@MainActor
final class AuthManager: ObservableObject {

    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var authError: String? = nil
    @Published private(set) var biometryType: LABiometryType = .none

    init() {
        detectBiometryType()
    }

    // MARK: - Public

    /// Attempt biometric or passcode authentication.
    func authenticate(reason: String = "Déverrouille Keibo") async {
        authError = nil
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to device passcode
            await evaluatePasscode(context: context, reason: reason)
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            isUnlocked = success
        } catch let laError as LAError {
            switch laError.code {
            case .userFallback:
                await evaluatePasscode(context: context, reason: reason)
            case .userCancel, .appCancel, .systemCancel:
                // User cancelled — leave locked, no error message
                break
            case .biometryNotEnrolled:
                authError = "Aucune donnée biométrique enregistrée. Veuillez activer Face ID dans les Réglages."
            case .biometryNotAvailable:
                authError = "La biométrie n'est pas disponible sur cet appareil."
            default:
                authError = laError.localizedDescription
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Unlock without authentication (when biometric is disabled in settings).
    func unlockWithoutAuth() {
        isUnlocked = true
    }

    func lock() {
        isUnlocked = false
    }

    // MARK: - Private

    private func detectBiometryType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        }
    }

    private func evaluatePasscode(context: LAContext, reason: String) async {
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isUnlocked = success
        } catch {
            authError = error.localizedDescription
        }
    }
}
