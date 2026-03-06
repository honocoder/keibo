import Foundation
import SwiftData
import Observation

/// Core business logic for Sillage's rolling budget cycle.
///
/// This class is intentionally kept free of SwiftData queries so it can be
/// unit-tested without a live ModelContext. Views fetch raw data via @Query and
/// pass it into BudgetManager methods to obtain derived values.
@MainActor
final class BudgetManager: ObservableObject {

    // MARK: - Published state
    @Published private(set) var cycleStart: Date
    @Published private(set) var cycleEnd: Date

    // MARK: - Init
    init(startDay: Int = 28) {
        let (s, e) = Self.computeCycleDates(startDay: startDay)
        self.cycleStart = s
        self.cycleEnd   = e
    }

    /// Call whenever UserConfig.startDayOfMonth changes.
    func refreshCycle(startDay: Int) {
        let (s, e) = Self.computeCycleDates(startDay: startDay)
        cycleStart = s
        cycleEnd   = e
    }

    // -------------------------------------------------------------------------
    // MARK: - Rolling cycle computation (the heart of the app)
    // -------------------------------------------------------------------------

    /// Computes the start and end dates of the rolling cycle that contains
    /// `reference`, given the user-configured `startDay`.
    ///
    /// Edge cases handled:
    /// - startDay > last day of a given month (e.g. 31 in February) → clamped
    ///   to the last day of that month.
    /// - Year boundaries (Dec → Jan).
    static func computeCycleDates(
        startDay: Int,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let today  = calendar.startOfDay(for: reference)
        let comps  = calendar.dateComponents([.year, .month, .day], from: today)

        let year   = comps.year!
        let month  = comps.month!
        let day    = comps.day!

        /// Returns the last valid day number for `startDay` in (year, month).
        func clamp(_ d: Int, toYear y: Int, month m: Int) -> Int {
            let anchor = calendar.date(from: DateComponents(year: y, month: m, day: 1))!
            let range  = calendar.range(of: .day, in: .month, for: anchor)!
            return min(d, range.upperBound - 1)
        }

        /// Returns a Date at midnight for the given (y, m, d), clamping d.
        func date(year y: Int, month m: Int, day d: Int) -> Date {
            let clamped = clamp(d, toYear: y, month: m)
            return calendar.date(from: DateComponents(year: y, month: m, day: clamped))!
        }

        let effectiveStartThisMonth = clamp(startDay, toYear: year, month: month)

        if day >= effectiveStartThisMonth {
            // Cycle started this month
            let cycleStart = date(year: year, month: month, day: startDay)

            var nm = month + 1
            var ny = year
            if nm > 12 { nm = 1; ny += 1 }

            let nextCycleStart = date(year: ny, month: nm, day: startDay)
            let cycleEnd = endOfDay(
                calendar.date(byAdding: .day, value: -1, to: nextCycleStart)!,
                calendar: calendar
            )
            return (cycleStart, cycleEnd)
        } else {
            // Cycle started last month
            var pm = month - 1
            var py = year
            if pm < 1 { pm = 12; py -= 1 }

            let cycleStart = date(year: py, month: pm, day: startDay)

            let thisCycleEnd = endOfDay(
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: date(year: year, month: month, day: startDay)
                )!,
                calendar: calendar
            )
            return (cycleStart, thisCycleEnd)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Spending helpers
    // -------------------------------------------------------------------------

    /// Total amount spent for `category` during the current cycle.
    func spent(for category: Category) -> Double {
        category.transactions
            .filter { $0.date >= cycleStart && $0.date <= cycleEnd }
            .reduce(0) { $0 + $1.amount }
    }

    /// 0…1+ progress ratio for `category` in the current cycle.
    func progress(for category: Category) -> Double {
        guard category.targetAmount > 0 else { return 0 }
        return spent(for: category) / category.targetAmount
    }

    /// Total spending across all non-savings categories in the current cycle.
    func totalSpent(categories: [Category]) -> Double {
        categories
            .filter { $0.type != .savings }
            .reduce(0) { $0 + spent(for: $1) }
    }

    /// "Reste à dépenser" — the headline metric on the dashboard.
    func remainingBudget(effectiveIncome: Double, categories: [Category]) -> Double {
        effectiveIncome - totalSpent(categories: categories)
    }

    // -------------------------------------------------------------------------
    // MARK: - Cycle management (called from views / settings)
    // -------------------------------------------------------------------------

    /// Fetches or creates the BudgetCycle record for the current period.
    /// Computes rollover from the most recent past cycle if one exists.
    @discardableResult
    func ensureCurrentCycle(
        in context: ModelContext,
        allCycles: [BudgetCycle],
        baseIncome: Double
    ) -> BudgetCycle {
        // Already exists?
        if let existing = allCycles.first(where: {
            $0.startDate == cycleStart && $0.endDate == cycleEnd
        }) {
            return existing
        }

        // Compute rollover from the most recent finished cycle
        let rollover = computeRollover(previousCycles: allCycles, baseIncome: baseIncome)

        let newCycle = BudgetCycle(
            startDate: cycleStart,
            endDate: cycleEnd,
            totalIncome: baseIncome,
            rolloverAmount: rollover
        )
        context.insert(newCycle)
        return newCycle
    }

    // -------------------------------------------------------------------------
    // MARK: - Rollover (zero-based: every unspent euro carries forward)
    // -------------------------------------------------------------------------

    /// Calculates the surplus from the most recently completed cycle.
    func computeRollover(previousCycles: [BudgetCycle], baseIncome: Double) -> Double {
        // Find the cycle that ended most recently before cycleStart
        guard let last = previousCycles
            .filter({ $0.endDate < cycleStart })
            .sorted(by: { $0.endDate > $1.endDate })
            .first
        else { return 0 }

        // We don't have access to categories here; rollover is stored on the
        // cycle itself when the cycle closes. Return stored value.
        return max(0, last.rolloverAmount)
    }

    /// Called when a cycle closes: computes unspent income and stores it.
    func closeCycle(
        _ cycle: BudgetCycle,
        categories: [Category],
        cycleStart: Date,
        cycleEnd: Date,
        oldCycleEnd: Date
    ) {
        // Temporarily swap the instance dates to query the closing cycle
        let savedStart = self.cycleStart
        let savedEnd   = self.cycleEnd
        self.cycleStart = cycleStart
        self.cycleEnd   = cycleEnd

        let spent = totalSpent(categories: categories)
        let surplus = max(0, cycle.effectiveIncome - spent)
        cycle.rolloverAmount = surplus      // store surplus so next cycle can read it

        self.cycleStart = savedStart
        self.cycleEnd   = savedEnd
    }

    // -------------------------------------------------------------------------
    // MARK: - Savings helpers
    // -------------------------------------------------------------------------

    /// Total saved in a savings category across ALL time (lifetime balance).
    func totalSaved(for category: Category) -> Double {
        category.transactions.reduce(0) { $0 + $1.amount }
    }

    // -------------------------------------------------------------------------
    // MARK: - Private helpers
    // -------------------------------------------------------------------------

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: 23, minute: 59, second: 59, of: date
        ) ?? date
    }
}
