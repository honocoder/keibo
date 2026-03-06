# Sillage — Setup Guide

## Requirements
- Xcode 15+
- iOS 17+ deployment target (SwiftData + `@Observable`)

## Project Setup

1. **Create a new Xcode project**
   - Template: *App* (SwiftUI, SwiftData)
   - Product Name: `Sillage`
   - Bundle ID: `com.yourname.sillage`
   - Interface: SwiftUI
   - Storage: SwiftData

2. **Replace generated files** with the ones in this folder:
   - Delete the auto-generated `Item.swift` and `ContentView.swift`
   - Drag all `.swift` files from this directory into the Xcode project navigator, maintaining the folder structure (Models/, Managers/, Views/…)
   - Check **"Create groups"** and ensure your target is selected

3. **Info.plist** — merge keys from `SillageInfo.plist`:
   - `NSFaceIDUsageDescription` → required for Face ID
   - Open `Info.plist` → right-click → *Open As → Source Code* → paste the keys

4. **Entitlements** — no special entitlements needed; Local Authentication works without them.

5. **Build & Run** on a real device (Face ID requires physical hardware).

## Architecture Overview

```
Sillage/
├── SillageApp.swift          — @main, ModelContainer setup
├── Models/
│   ├── CategoryType.swift    — Enum: Fixe | Variable | Épargne
│   ├── UserConfig.swift      — @Model: startDayOfMonth, income, biometric
│   ├── Category.swift        — @Model: name, icon, type, targetAmount
│   ├── Transaction.swift     — @Model: amount, date, note, category?
│   └── BudgetCycle.swift     — @Model: startDate, endDate, income, rollover
├── Managers/
│   ├── BudgetManager.swift   — Rolling cycle computation + spending helpers
│   └── AuthManager.swift     — LAContext Face ID / Touch ID wrapper
└── Views/
    ├── DesignSystem.swift    — Colors, glassmorphism modifier, haptics
    ├── ContentView.swift     — TabView + LockScreen gate
    ├── Dashboard/
    │   ├── DashboardView.swift    — Main screen (hero, fixed rows, envelope grid)
    │   ├── EnvelopeCard.swift     — Animated fill card (variable categories)
    │   └── FixedExpenseRow.swift  — Paid/unpaid toggle row
    ├── Savings/
    │   └── SavingsView.swift      — Savings accounts with progress
    ├── History/
    │   └── HistoryView.swift      — Searchable transaction log
    └── Settings/
        └── SettingsView.swift     — Cycle day, income, biometric, categories
```

## Key Logic: Rolling Cycle

`BudgetManager.computeCycleDates(startDay:reference:)` handles all edge cases:

| Scenario | Behaviour |
|----------|-----------|
| startDay=28, today=Mar 15 | Cycle: Feb 28 → Mar 27 |
| startDay=28, today=Mar 29 | Cycle: Mar 28 → Apr 27 |
| startDay=31, today=Feb 05 | Clamped to Jan 31 → Feb 28/29 |
| Dec 31 → Jan boundary     | Year incremented correctly |

## Zero-Based Rollover

When a new cycle starts, `BudgetManager.ensureCurrentCycle(in:allCycles:baseIncome:)` reads the `rolloverAmount` stored on the previous `BudgetCycle` record and adds it to `effectiveIncome`. Every unspent euro automatically carries forward.
