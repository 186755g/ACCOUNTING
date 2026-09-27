# حساباتي — Technical Architecture (Phase 1)

## Scope

Phase 1 establishes the Flutter project, architectural boundaries, localization
foundation, navigation entry point, and technology decisions. It intentionally
does not implement sales, inventory, accounting, or other business workflows.

## Folder structure

```text
lib/
  app/                         Application composition and theme
  core/
    localization/              Arabic/English localization
    database/                   Database connection and migrations (Phase 2)
    error/                      Typed failures and user-safe error mapping
    formatting/                 Currency/date formatting by country
    services/                   Cross-feature services
  features/
    dashboard/
      data/                     Dashboard data sources/repositories
      domain/                   Dashboard entities/use cases
      presentation/             Dashboard screens/controllers/widgets
    products/                   Products and categories
    sales/                      Sales and returns
    purchases/                  Purchases and stock receiving
    customers/                  Customers and receivables
    suppliers/                  Suppliers and payables
    debts/                      Debt tracking
    expenses/                   Expenses
    analytics/                  Profit, loss, and trends
    reports/                    Reports and export
    settings/                   Profile, backup, restore, and preferences
```

Each feature follows `presentation -> domain -> data`. Presentation does not
query the database directly; domain use cases contain business rules; data
repositories abstract local storage and future remote synchronization.

## State management

The application will use Riverpod when the first stateful business workflow is
introduced (Phase 3+). Providers will own loading, empty, success, and error
states and will be disposed at feature boundaries. Phase 1 keeps state limited
to the app locale so no state-management dependency is added prematurely.

## Database and offline-first strategy

Drift over SQLite is the planned local database for typed schemas, migrations,
transactions, and reliable offline operation. Repository interfaces will allow
an optional remote sync service later without coupling UI to a backend.
Sensitive backup files will be encrypted before export; credentials and API
keys will never be stored in source code.

## Major entities

`Business`, `UserProfile`, `Product`, `Category`, `Customer`, `Supplier`,
`Sale`, `SaleItem`, `Purchase`, `PurchaseItem`, `StockMovement`, `Debt`,
`Expense`, `Payment`, `Currency`, `Notification`, and `BackupMetadata`.

Money is represented as integer minor units with an ISO currency code. EGP is
the initial currency. Dates are stored in UTC and formatted for the Egypt
locale/time zone at the presentation boundary.

## Navigation

The root route is the dashboard. A bottom navigation shell will be introduced
with Dashboard, Sales, Products, Customers, and More sections once those
features exist. Secondary modules (purchases, suppliers, debts, expenses,
analytics, reports, notifications, settings, and backup) will use named routes
behind the More section. Navigation guards will be added when authentication or
business selection is introduced.

## Dependencies

Current dependencies are intentionally minimal:

- `flutter_localizations`: framework localization delegates and RTL support.
- `cupertino_icons`: icon compatibility for platform-consistent UI.
- `flutter_test` and `flutter_lints`: test and static-analysis tooling.

Planned additions when their phases begin:

- `riverpod` / `flutter_riverpod`: feature state management.
- `drift` and `sqlite3_flutter_libs`: typed offline database.
- `intl`: currency and Egypt-aware date formatting.
- `file_picker` and `share_plus`: user-initiated backup/export flows.
- `flutter_secure_storage`: protected local secrets, only if needed.

Packages will be added only when used by a real feature and checked for
maintenance, platform support, and licensing.

## Localization and RTL

Arabic is the default locale and all user-facing strings go through
`AppLocalizations`. English is supported from the initial shell. Feature
translations will move to generated ARB files once the first full module is
implemented. UI layout uses Flutter's directionality system rather than
hard-coded left/right assumptions.

## Android readiness

The generated Android project targets the current Flutter stable defaults.
`flutter doctor` reports that Android SDK command-line tools are missing on this
machine; installing them through Android Studio or the Android SDK manager is
required before an Android emulator/device build can run. Web launch is used
for Phase 1 smoke validation in this environment.
