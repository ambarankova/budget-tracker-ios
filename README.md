# Budget — Personal Finance Tracker

A SwiftUI iOS app for tracking personal income and expenses, visualising spending by category, managing savings goals, and viewing multi-currency balances.

---

## Features

- **Expense & income tracking** — add transactions by category with free-text amounts
- **Annual analytics table** — monthly breakdown per category with editable budget plans
- **Charts** — pie chart and bar chart views for the selected year
- **Savings goals** — set a target amount, top up progress, and track history
- **Multi-currency** — transactions stored in any currency, converted to the base currency via the CBR (Central Bank of Russia) XML API
- **Localisation** — Russian and English, driven by SwiftGen-generated `L10n` constants

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Architecture | MVVM (`ObservableObject` ViewModels) |
| Persistence | `UserDefaults` (cents-based storage with v1→v2 migration) |
| Currency rates | CBR XML API (`actor`-based service with in-memory cache) |
| Code generation | [SwiftGen](https://github.com/SwiftGen/SwiftGen) (strings, assets) |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| Tests | XCTest (logic tests — no host app required) |
| Minimum deployment | iOS 16 |

---

## Architecture

```
Budget/
├── App/                    # Entry point, AppDependencies composition root
├── Modules/
│   ├── FinanceDashboard/   # Monthly view — ViewModel + View
│   ├── Analytics/          # Annual table + charts — ViewModel + View
│   └── Goals/              # Savings goals — ViewModel + View
├── Models/                 # Transaction, Goal, FinanceMode
├── Services/               # Repositories, CurrencyConverter, CBRCurrencyRateService
├── UIComponents/           # Reusable views (BottomMenuBar, etc.)
├── Extensions/             # SwiftUI + Foundation helpers
├── Resources/              # Assets, fonts, localization strings
└── Generated/              # SwiftGen output (Strings.swift, Assets.swift)

BudgetTests/
├── AppMoneyTests.swift         # Parsing, formatting, normalizing money input
├── CurrencyConverterTests.swift# Currency conversion logic
└── RepositoryTests.swift       # Mock repository save/load/rename
```

**Key design decisions:**

- Money is stored as `Int` cents to avoid floating-point rounding.
- All dependencies are injected through `AppDependencies` — `.live` in production, `.preview` in SwiftUI previews, mock implementations in tests.
- Test target compiles source files directly (logic tests) to avoid the Xcode 15 "Multiple commands produce Budget.swiftmodule" issue with hosted tests.

---

## How to Build

**Prerequisites**

```bash
brew install xcodegen
brew install swiftgen
```

**Steps**

```bash
git clone <repo-url>
cd Budget
xcodegen generate     # creates Budget.xcodeproj from project.yml
open Budget.xcodeproj
```

Select the **Budget** scheme and a simulator, then press **⌘R**.

> `project.yml` is the source of truth for project structure. Regenerate the `.xcodeproj` after any changes to it.

---

## Running Tests

```bash
xcodebuild test \
  -scheme BudgetTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press **⌘U** inside Xcode with the **BudgetTests** scheme selected.
