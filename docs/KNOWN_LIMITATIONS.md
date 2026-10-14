# Known limitations

- The Android application ID is still `com.example.hesabati`; the product
  owner must approve and configure a unique distribution ID.
- Release builds use Android's debug key until a private release signing
  configuration is supplied. The generated APK is verification-only.
- Portable backups contain business and customer data but are not encrypted.
- Alerts are checked when the app starts/resumes. Optional daily sales
  summaries report the previous local day when the app is opened on a new day;
  background scheduled delivery is not active.
- Cloud sync/backup is not implemented. Core records, reports, and workflows
  are local and work offline.
- Schema version 8 introduces a local-only change outbox that records
  create/update/delete operations for categories, products, sales, purchases,
  payments, and debts. It does not send data, queue existing records,
  deduplicate operations across devices, or resolve conflicts.
- A local pending row in `sync_outbox` is not evidence of successful delivery or
  server acknowledgement; there is no complete network sync implementation yet.
- If the installation identity is unavailable, local business changes may still
  be stored locally without creating a journal row. Those edits remain local-only
  until a dedicated recovery mechanism is implemented and are not replayed
  automatically when the installation identity becomes available again.
- The installation ID is stored outside the business database and portable
  backups. It is not hardware-bound and may be duplicated if the complete
  private app data directory is copied. Outbox rows are part of `.hdb` database
  snapshots, so future delivery must define restored-pending-event handling.
- Product browsing, party records, purchase/sales histories, and large report
  analysis lists are now paginated with limit/offset queries. The service and
  screen layers respect search/date/filter resets and retry states, but the full
  widget-level large-list flow remains unconfirmed in this Linux test
  environment.
- The financial-account ledger is implemented at the database and repository
  layer, but the dedicated account-management and daily-reconciliation UI is
  still pending. The core schema supports cash, bank, card, and wallet account
  types, book balance tracking, and reconciliation variance records.
- Notification presentation, receipt printing, file sharing, and file picking
  depend on their host-platform integrations and require device-level testing.
- No clean-device Android install, store listing, production signature, or
  store compliance review can be asserted until release credentials and the
  final package identity are supplied.
