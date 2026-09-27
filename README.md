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
