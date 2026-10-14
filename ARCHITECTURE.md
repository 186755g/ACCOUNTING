# حساباتي — Technical Architecture

## Scope

The application is an Arabic-first, offline-first Flutter app. Implemented
vertical slices include local account settings, product/category management,
inventory management, point of sale, customer and supplier accounts, purchases,
financial analytics, search, and report export.

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
    account/                     Business profile, alerts, backup, and restore
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
receipt view that can be shared through the platform share sheet or printed
through the platform print dialog. Printing rasterizes the rendered receipt so
Arabic product names and right-to-left layout are preserved.

Purchase checkout records received quantities, purchase-time unit cost, tender
payments, and supplier payables atomically. Customer receivables and supplier
payables are separate debt directions. Partial and full debt payments are
stored as payment transactions; account totals and outstanding balances are
calculated from sales or purchases, debts, and payments rather than saved as
mutable customer or supplier totals. Customer and supplier screens expose
transaction and debt histories.

`FinancialService` is the single source for dashboard, trend, report, and
product/customer performance calculations. Money calculations use integer
minor units, including deterministic allocation of order-level discounts to
sale lines. Net sales subtract recorded discounts and explicit return refunds;
COGS uses the sale-time cost snapshot and is reversed for returned quantities;
gross profit is net sales minus net COGS, and net profit subtracts operating
expenses. Customer debt collections and supplier debt payments are exposed as
cash-flow metrics and never counted again as revenue or expenses. Product
returns now store the actual refunded amount and a cumulatively rounded
returned-cost allocation in minor units; upgrades backfill legacy refunds using
the original sale-line amount as an estimate.

The dashboard loads its daily KPIs, recent sales, stock alerts, outstanding
balances, and trends from SQLite. Analytics and reports share the same
financial service and support date ranges, time buckets, and relevant entity
filters. CSV exports are UTF-8 with a BOM and PDF reports include business
identity, totals, and product performance. Global search covers products,
customers, suppliers, sales, and purchases; dedicated sales and purchase
histories add date, party, and payment-status filters.

CSV fields are quoted and spreadsheet-formula prefixes are neutralized before
export. Product browsing uses 50-record keyset-free offset pages; other
histories and search surfaces use bounded queries where configured.

Local notifications are opt-in in profile settings. Stock, customer debt,
overdue-payment, and previous-day sales summaries are queried from the local
financial service when the app starts/resumes and every 15 minutes while an
alert preference is enabled and the app remains in the foreground. Delivery
fingerprints are stored in SQLite, resolved alerts are cleared, and a six-hour
cooldown limits repeat alerts. Notification content avoids customer names and
exact debt amounts. Background scheduling is exposed behind a scheduler
interface but not enabled; daily summaries appear when the app is opened on a
new local day.

Backups are created from a consistent SQLite `VACUUM INTO` snapshot and
streamed into a gzip-compressed `.hdb` envelope containing format/schema
versions, a timestamp, byte count, and SHA-256 digest. Restore validates the
archive and database before it closes the active connection. Replacement uses
a rollback snapshot and returns a reopened database handle. A
`BackupTransport` port separates local share/file-picker transfer from backup
creation so another transport can be introduced without requiring cloud
services. The archive is streamed and limited to a 1 GiB uncompressed database.
Portable backups are not encrypted in this version.

Repository APIs are storage boundaries for the feature data layers; screens
should not query SQLite directly. Remote sync can be introduced later without
coupling features to a backend. Credentials and API keys must not be stored in
source code. Exported backup files contain local business data and should be
stored securely by the user.

The current synchronization foundation is intentionally local-only. Schema
version 8 provides a `sync_outbox` journal and category create/update/delete
operations write journal entries in the same SQLite transaction as the
category change. The journal starts empty for existing databases; no legacy
business data is queued. There is no network client, server, account system,
acknowledgment, or conflict resolution yet. Operation IDs are unique within
one database only and require server-side idempotency before any future
delivery can be considered safe.

An installation ID is persisted in a separate file under the platform
application-support directory, outside SQLite snapshots and `.hdb` backup
files. Android app backup is disabled in the manifest. This does not protect
against copying the complete private application data directory, and must not
be treated as a hardware-bound or tamper-proof identity.

## Navigation

The root route is the dashboard. Sales, products, inventory, reports, and
global search are available from the dashboard; a business-management menu
opens customers, suppliers, and purchases. Navigation guards will be added
when authentication or business selection is introduced.

## Dependencies

Current dependencies include:

- `flutter_localizations`: framework localization delegates and RTL support.
- `cupertino_icons`: icon compatibility for platform-consistent UI.
- `sqflite` and `path`: versioned local SQLite storage and database paths.
- `path_provider`: temporary locations for generated reports.
- `pdf` and `printing`: generate Arabic-compatible report PDFs and print
  rasterized sale receipts.
- `assets/fonts/NotoSansArabic.ttf`: embedded Arabic PDF font under the SIL
  Open Font License; its license is stored beside the font.
- `share_plus`: sharing sale receipts through the platform share sheet.
- `flutter_local_notifications`: opt-in local business alerts.
- `file_picker`: user-selected local backup restore.
- `crypto`: backup SHA-256 integrity validation.
- `flutter_test` and `flutter_lints`: test and static-analysis tooling.

`sqflite_common_ffi` provides in-memory SQLite tests on desktop/CI.
Dependencies are added only when used by a real feature and checked for
maintenance, platform support, and licensing.

## Localization and RTL

Arabic is the default locale and all user-facing strings go through
`AppLocalizations`. English is supported from the initial shell. Feature
translations will move to generated ARB files once the first full module is
implemented. UI layout uses Flutter's directionality system rather than
hard-coded left/right assumptions.

## Android readiness

Android notifications declare the Android 13+ notification permission and use
core-library desugaring. The app label is Hesabati. The application ID remains
the template value `com.example.hesabati`, and release signing still uses the
debug key until the owner configures a private production keystore.

For setup, release, and verification details see
[docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md).
