import SwiftUI
import SwiftData

@main
struct SillageApp: App {

    // MARK: - Environment objects (shared across the app)
    @StateObject private var budgetManager = BudgetManager()
    @StateObject private var authManager   = AuthManager()

    // MARK: - SwiftData container

    let modelContainer: ModelContainer = {
        let schema = Schema([
            UserConfig.self,
            Category.self,
            Transaction.self,
            BudgetCycle.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer could not be created: \(error)")
        }
    }()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetManager)
                .environmentObject(authManager)
        }
        .modelContainer(modelContainer)
    }
}
