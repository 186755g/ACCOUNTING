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

Implemented screens use local Flutter state. Basic local offline workflows do
not require server authentication; however, the future online architecture uses
centralized server-side authentication and explicit store-scoped access.

## Authentication and multi-store access model (future online phase)

The next online phase introduces a centralized server that authenticates users,
tracks device registrations, and binds each device to the stores the user is
allowed to access. The local installation ID remains a device-local identifier
only. It is not used as a proof of user identity, device authorization, or
store ownership.

The architecture separates three distinct layers:

1. User authentication session
   - Represents the authenticated user on the server.
   - Includes user_id, session_id, access token, refresh token, expiry, and
     revocation status.
   - Validates the user before any protected API request.

2. Device registration and lifecycle
   - Represents the physical app instance or device owned by a user.
   - Includes device_id, user_id, platform, device name, registration status,
     and active/revoked state.
   - Reenabled access requires an explicit rebind flow; revocation is never
     automatically reversed by a normal login or by a stale refresh token.

3. Store-scoped access context
   - Represents the permission of a registered device to interact with one store.
   - Includes device_id, store_id, user_id, access status, active session
     binding, and store-specific sync state such as cursor and last sync
     checkpoint.
   - Each store has its own access context, sync state, and pending data flow.
   - Users may own multiple stores, and a device may be authorized for multiple
     stores, but requests are always validated against the active store_id.

The server must validate all of the following before accepting a protected
request: user session valid, device active, user still has membership in the
requested store, device has active access for that store, and the request is
using the correct store context. Device-store access is not a substitute for
user membership validation.

The user session and the store access context are intentionally different. A
user may remain authenticated while switching among stores they are allowed to
access without re-entering credentials for each switch. A device may register
once and then open multiple store contexts as long as the server authorizes
those store contexts.

A device revocation is stronger than a session logout. Revoking a device invalidates
all active sessions for that device and rejects protected requests until the
device is explicitly rebound with a fresh, authorized re-registration flow.

### Auth and device lifecycle APIs

The future server contract uses a strict sequence:

- `POST /v1/auth/register` — create a user account
- `POST /v1/auth/login` — authenticate and create a user session
- `POST /v1/auth/logout` — revoke the current session
- `POST /v1/auth/refresh` — rotate the refresh token and issue a new access
  token
- `DELETE /v1/auth/sessions/{sessionId}` — revoke a specific session
- `POST /v1/devices/register` — register a device for a user
- `POST /v1/devices/{deviceId}/revoke` — revoke a device and invalidate all
  related sessions
- `POST /v1/devices/rebind` — explicit reactivation flow for a revoked device
- `POST /v1/stores` — create a store
- `GET /v1/stores` — list stores visible to the authenticated user
- `POST /v1/stores/{storeId}/switch` — activate a store-scoped context
- `POST /v1/sessions/validate` — validate user session, device status, and
  store access before reconnecting sync flows

The rebind flow must be explicit and authorized by a user with authority over the
store or device ownership. It cannot be completed through a normal login, a
stale refresh token, or the local installation ID. All rebind approvals and
revocations are recorded in an audit log with actor, timestamp, reason, and
related device/session/store IDs.

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

### Movement identity and idempotency guarantees

The local movement model separates three identifiers that are intentionally not
interchangeable:

- `id`: the row-level SQLite identity for a persisted movement record.
- `operation_id`: the local lifecycle ID recorded in
  `financial_operation_registry` for a retried business operation.
- `source_type + source_id`: the semantic idempotency key for a movement or a
  retried operation. A repeated retry with the same business key must not create a
  second movement row.
- `event_id`: the sync-event identity used by outbox records and not treated as a
  movement identity itself.

The current local implementation enforces idempotency checks in repository logic
before inserting new movement rows. If a duplicate `source_type` + `source_id`
combination is encountered with the same payload, the code returns the existing
record instead of creating another row. If the same source identity is reused with
conflicting content, the repo raises `MovementIdentityConflictException` rather
than silently overwriting data. This prevents accidental replays of the same
business action while leaving a visible safety signal for conflicting retries.

The repository does not add a new SQLite UNIQUE constraint for legacy movement
rows or for `source_type + source_id` because older data may already contain
repeated or non-normalized values. The project therefore treats this as a
runtime guard and a documented conflict signal, not as a migration-backed
uniqueness guarantee. Database-level atomic protection for concurrent writers
remains a separate design decision and is not claimed by the current code.

This is sufficient for local-first replay protection in non-concurrent single-app
usage, but it does not prove safe deduplication under parallel writers unless the
schema is later upgraded with a verified uniqueness constraint and a cleanup plan.
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
be treated as a hardware-bound or tamper-proof identity. The installation ID
is not used to grant access or prove user ownership.

## Navigation

The root route is the dashboard. Sales, products, inventory, reports, and
global search are available from the dashboard; a business-management menu
opens customers, suppliers, and purchases. Future authentication and store
selection will use an explicit store-scoped route guard that validates the
user session, active device registration, and the selected store context before
allowing access.

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

## Acceptance criteria for the first online auth/store/device phase

The design is acceptable when the following can be demonstrated in a follow-up
implementation review:

- A user can register and log in using valid credentials.
- A valid user session is distinct from the store-scoped access context.
- A user with multiple stores can switch between authorized stores without new
  login credentials for each switch.
- A registered device can access multiple authorized stores, each with its own
  sync state and cursor.
- A revoked device cannot create new sessions, cannot sync, and cannot access
  protected requests until a fresh rebind approval is granted.
- A regular login, stale refresh token, or installation ID cannot re-enable a
  revoked device.
- A store-scoped request cannot change its store_id to access another store.
- User membership is required before any store access is granted.
- Local offline work continues without a server connection, and reconnect
  triggers explicit validation before resuming online activity.
- Device logout, session revocation, and full device revocation have distinct
  and testable effects.
- All sensitive actions are recorded in an audit log with actor, target, time,
  reason, and result.

## Closed design decisions

- Centralized online server is the required coordination layer.
- Local offline work remains valid and must not require immediate online
  authentication.
- Users may own multiple stores.
- Devices may access multiple authorized stores, with separate access state and
  sync cursor per store.
- installation_id is not an authentication or authorization mechanism.
- Revoked devices do not resume automatically and require explicit rebind.
- Financial sync and monetary transaction sync remain outside the first phase.

## Open technical decision before implementation

One design decision still needs explicit approval before implementation starts:
whether device rebind is approved by the same user only, or by a separate
owner/admin role for each store. This affects the authorization model for
device rebind requests and the exact audit policy for those approvals.
