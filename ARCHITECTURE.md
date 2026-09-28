# حساباتي — Technical Architecture

## Scope

The application is an Arabic-first, offline-first Flutter app. Implemented
vertical slices include local account settings, product/category management,
inventory management, and a point-of-sale flow with payment/debt recording.

## Folder structure

```text
lib/
  app/                         Application composition and theme
  core/
    localization/              Arabic/English localization
    database/                   SQLite connection, models, repositories, migrations
    error/                      Typed failures and user-safe error mapping
    formatting/                 Currency/date formatting by country
    services/                   Cross-feature services
  features/
    dashboard/
      data/                     Dashboard data sources/repositories
      domain/                   Dashboard entities/use cases
      presentation/             Dashboard screens/controllers/widgets
    products/                   Product and category management
    inventory/                  Stock adjustments, history, and alerts
    sales/                      Point of sale and sale detail/receipt view
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

The database models and repositories provide typed persistence boundaries.
Feature presentation currently coordinates local repository operations
directly; use cases and a shared state-management layer remain future
refactoring options as workflows expand.

## State management

Implemented screens use local Flutter state. No provider framework or online
authentication is required for basic offline usage.

## Database and offline-first strategy

The local persistence layer uses SQLite through `sqflite`. Open the database
through `LocalDatabase.open()` and access typed repositories from
`lib/core/database/database.dart`. The SQLite schema is versioned; schema
changes require an explicit version increment and migration.

Sales and purchases are aggregates: each has one or more item rows and header
totals. Creating or updating a document and replacing its items runs in one
SQLite transaction. A sale item stores its product ID and name snapshot,
quantity, selling price, cost price, discount, and total. The stored cost price
is the historical unit cost at the time of sale; later product price edits do
not change the recorded sale or its profit inputs. Referenced products cannot
be hard-deleted while historical items reference them.

Money is represented as integer minor units in the active ISO currency
(`EGP` by default); quantities are decimal values to support fractional units.
Dates are stored as UTC epoch milliseconds. Generic repositories support
create, read, update, delete, text search, equality filters, date ranges,
sorting, and pagination. Search and filter fields are allow-listed per entity.
The database uses foreign keys, check constraints, and indexes for common
relationships and date queries. Customer debts are receivables; supplier debts
are payables. Payments reference exactly one sale, purchase, debt, or expense.

Products persist SKU and unique barcode identifiers, category, image path,
unit, purchase and selling prices, stock and minimum stock, description,
active status, and UTC creation/update dates. Barcodes are indexed and included
in local search to provide a stable lookup seam for future scanner integration.
Deleting a category leaves its products in place with no category; products
referenced by historical sale or purchase items cannot be hard-deleted.

Inventory movements are persisted with the product/name snapshot, signed
quantity change, previous and resulting quantities, reason, UTC date, optional
note, and optional source document. Product opening balances, completed sales,
received purchases, transaction edits/deletions, sale returns, and manual
adjustments all update stock and history atomically. Returns are tied to the
original sale item and cannot exceed its unreturned quantity. Stock cannot fall
below zero unless the persisted `allow_negative_stock` setting is enabled.
Active products at or below their minimum stock have low-stock alerts; products
at zero or below have out-of-stock alerts.

The POS writes completed sales through one repository transaction that also
deducts inventory, stores payment tender rows, and creates a customer receivable
for any unpaid balance. The checkout API accepts a list of tenders so mixed
payments can be expanded without changing the sale schema. The initial UI
offers cash, card, wallet, or fully unpaid checkout. Sale item price and cost
snapshots are read from the current product when checkout begins; later product
edits do not alter historical sale details. Sale details form a readable
receipt view; device printing and sharing are deferred.

Repository APIs are storage boundaries for the feature data layers; screens
should not query SQLite directly. Remote sync can be introduced later without
coupling features to a backend. Sensitive backup files must be encrypted before
export; credentials and API keys must not be stored in source code.

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
- `sqflite` and `path`: versioned local SQLite storage and database paths.
- `sqflite_common_ffi`: in-memory SQLite tests on desktop/CI.
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
