# حساباتي | Hesabati

An offline-first sales and business management app for small businesses, built
with Flutter.

## UI foundation

The app includes an Arabic-first responsive dashboard, English/Arabic locale
switching with RTL support, light and dark themes, and reusable components
exported from `lib/core/widgets/app_widgets.dart`. Dashboard figures are sample
content until business data is connected.

Local persistence uses SQLite via `sqflite`. Typed models, the versioned
schema, and CRUD/search/filter repositories are exported from
`lib/core/database/database.dart`. Sales and purchases store line items
transactionally; sale items retain their historical product cost and price
snapshots.

Product and category management runs entirely offline. Products support SKU
and unique barcode identifiers, categories, image paths, prices, inventory
thresholds, status, and timestamps. Barcode values are searchable and indexed
for future scanner integration.

Inventory is updated transactionally when received purchases and completed
sales are created, edited, or deleted. Sale returns and manual stock
adjustments are recorded in an inventory history with before/after quantities,
reason, date, and optional note. The inventory screen surfaces low-stock and
out-of-stock alerts. Negative stock is blocked by default and can be enabled in
the business profile settings.

The point-of-sale workflow supports searchable product selection, cart quantity
changes, order discounts, optional customers, and cash, card, wallet, or unpaid
checkout. Checkout accepts multiple tenders for mixed-payment expansion; unpaid
balances create a customer receivable. Sale details show item, payment, and
cost-at-sale snapshots. Receipt printing/sharing is intentionally left for a
later phase.

## Run and verify

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

## Build APK on GitHub

The workflow in `.github/workflows/build-apk.yml` runs tests and builds a
release APK when changes are pushed to `main` or `master`, or when started
manually from the **Actions** tab. Download `hesabati-release-apk` from the
completed workflow run's **Artifacts** section. The APK uses Android's debug
signing key for testing; publishing through Google Play requires a private
release keystore and signing secrets.
