# Database guide

## Location and access

The application uses one local SQLite database, `hesabati.db`, opened through
`LocalDatabase.open()`. Tests can provide a separate database path and
`DatabaseFactory`. Typed models and repositories are exported from
`lib/core/database/database.dart`.

SQLite foreign-key enforcement and a busy timeout are enabled on each app
connection. Application money is stored in integer minor units; quantities
and inventory snapshots use real-valued quantities. Dates are UTC epoch
milliseconds.

On Android, the database remains in the app's private storage sandbox and
platform-managed application backup is disabled. SQLite is not encrypted at
rest; portable `.hdb` backups are also currently unencrypted.

## Main tables

| Tables | Purpose |
| --- | --- |
| `categories`, `products` | Product catalog, identifiers, prices, and stock |
| `sales`, `sale_items`, `product_returns` | Completed sale headers, immutable line snapshots, and returns |
| `purchases`, `purchase_items` | Received stock and supplier purchase snapshots |
| `customers`, `suppliers` | Business contacts |
| `debts`, `payments` | Separate receivables/payables and their payment ledger |
| `expenses`, `users` | Operating costs and optional user attribution |
| `inventory_history` | Auditable stock movements with before/after quantities |
| `app_settings` | Business profile and notification preferences |
| `notification_deliveries` | Alert fingerprints and cooldown timestamps |

Sales, purchases, their item rows, payment tenders, debt creation, and inventory
changes are written within repository transactions. A product cannot be hard
deleted while historical sale/purchase or inventory references remain.

Outstanding customer and supplier balances are derived from debt entries minus
payments. They are not treated as editable totals. Sale-time cost, price,
discount, and product-name snapshots preserve historical reporting when the
catalog later changes.

## Schema migrations

The current schema version is **8** (`LocalDatabase.databaseVersion`).
Increment it for every schema change and add a forward migration in
`LocalDatabase._upgradeSchema`. Migrations must work from every supported old
version and preserve data. Fresh schema creation and migration paths must
produce the same current tables and constraints. Keep migration tests using a
real legacy schema fixture in `test/database_test.dart`.

Version 7 adds five disabled-by-default notification settings and the
`notification_deliveries` deduplication table. The table uses
`CREATE TABLE IF NOT EXISTS` in migration to accommodate older upgrade paths
that create inventory schema at the same time.

Version 8 adds the local `sync_outbox` change journal. It starts empty when
upgrading an existing database and does not backfill existing business rows.
The category repository writes category create, update, and delete entries in
the same SQLite transaction as the category change. Entries include a unique
operation ID, installation ID, entity and operation identifiers, a JSON
snapshot, insertion sequence, timestamp, and local pending status. A unique
constraint protects operation IDs within this database; without a server and
server-side idempotency checks, this is not a guarantee against duplicate
processing across devices or copied databases.

This is a local synchronization foundation only, not a complete network-sync
system. The outbox is for local journaling and future delivery planning; it is
not a server sync client, acknowledgment tracker, conflict resolver, or
networked replication protocol. A row in `sync_outbox` should be treated as a
local pending event, not as proof that a remote server has received or applied
it.

When the installation identity is unavailable, category changes can still be
written to the local database, but the app intentionally defers creating a
`sync_outbox` entry for that operation. Those local changes are not replayed or
reconstructed automatically when the installation identity becomes available
again; they remain a local-only state until a dedicated recovery or sync
policy is implemented.

The installation ID is stored separately from SQLite at the platform
application-support location, not in `sync_outbox` or portable `.hdb` backups.
Android currently disables platform-managed app backup in its manifest.
Copying the entire private app data directory, reinstalling the app, or
platforms with different backup behavior are outside this identity guarantee.
An invalid identity file is reported rather than silently replaced.

The outbox is local-only in this release: there is no network sender,
acknowledgment, conflict resolution, or legacy-data upload. Portable backup
and restore still copy/replace the database; they are not synchronization.
Because `.hdb` snapshots include the outbox table but not the separate
installation ID, a future sync implementation must explicitly define how to
handle pending journal rows restored onto another installation before sending
any of them.

## Backup format and restore

`.hdb` files contain the `HESABATI` magic signature, a bounded JSON metadata
header, and a gzip-compressed SQLite snapshot. Metadata carries the archive
format version, exact schema version, UTC creation time, uncompressed size,
and SHA-256 digest. The current implementation bounds uncompressed database
files to 1 GiB and streams decompression while enforcing the declared size.

Restore rejects malformed, corrupt, or incompatible input before closing the
live connection. It checks SQLite integrity, foreign keys, schema version,
required tables, and the business-settings row. Database replacement makes a
second `VACUUM INTO` rollback snapshot first. If replacement fails, the
previous database is restored and reopened. Keep destructive file operations
limited to the explicitly resolved database, temporary snapshot, and SQLite
sidecar paths.

The archive is currently **not encrypted**. Do not assume file-system sharing
or transport encryption protects backups at rest.
