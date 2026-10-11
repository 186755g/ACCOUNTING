# حساباتي | Hesabati

Hesabati is an Arabic-first, offline-first sales and business management app
for small businesses. It runs locally with Flutter and SQLite; internet is not
required for core business workflows.

## Features

- Arabic/English interface, RTL layout, and system/light/dark themes.
- Local product, category, inventory, customer, supplier, and expense records.
- Point of sale with item and order discounts, cash/card/wallet/debt tenders,
  mixed-tender storage, receipt sharing/printing, and sale-time cost snapshots.
- Purchases, stock movements, sale returns, receivables, payables, and partial
  or full debt payments.
- Centralized financial calculations for sales, discounts, refunds, cost of
  goods, expenses, gross profit, and net profit.
- Dashboard, date-filtered business analytics, global search, CSV/PDF reports.
- Opt-in local stock/debt alerts and an optional previous-day sales summary.
- Integrity-checked local backups with portable export and guarded restore.

## Requirements and setup

Install Flutter (stable), the Dart SDK required by `pubspec.yaml`, and—if
building Android—the Android SDK and Java 17.

```sh
flutter pub get
flutter run
```

To run the test suite and static analysis:

```sh
flutter test
flutter analyze
```

The local database is created on first launch. Business records and settings
are stored on the device. Notification preferences are off by default; the app
requests notification permission only when a user enables a notification type.

## Backup and privacy

Create and export a backup from **Business profile → Backup**. Restore accepts
Hesabati `.hdb` backups only, checks the format, schema, SHA-256 digest, SQLite
integrity, and foreign-key references before replacing local data. The app
keeps a rollback snapshot during replacement and asks for confirmation first.
Backups are **not encrypted** in this version and contain business and customer
data. Store exported files in a private, trusted location.

## Android builds

```sh
flutter build apk --release
```

The current Android application ID (`com.example.hesabati`) is a template
placeholder and must be replaced with an owner-approved, unique ID before
distribution. Without a private release keystore, this project’s release
variant uses Android's debug signing key and is for verification only—not
Google Play or public distribution. Never commit keystore files or passwords.

The GitHub Actions workflow at `.github/workflows/build-apk.yml` tests and
builds an APK on pushes to `main`/`master` and on manual dispatch. Its artifact
is also debug-signed unless signing is configured outside the repository.

## Documentation

- [Architecture](./ARCHITECTURE.md)
- [Database schema and migration guide](./docs/DATABASE.md)
- [Release checklist](./docs/RELEASE_CHECKLIST.md)
- [Known limitations](./docs/KNOWN_LIMITATIONS.md)
- [Roadmap](./docs/ROADMAP.md)

## License and assets

The Arabic PDF font is Noto Sans Arabic under the SIL Open Font License; the
font license is included alongside the asset.
