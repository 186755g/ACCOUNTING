# Release checklist

## Before distribution

- [ ] Choose and reserve an owner-approved Android application ID; replace
  `com.example.hesabati` in `android/app/build.gradle.kts`.
- [ ] Configure a private release keystore and signing credentials through
  the build environment/secret manager. Do not commit secrets.
- [ ] Set and increment `version` in `pubspec.yaml`.
- [ ] Review app label, launcher icon, splash screen, and the final installed
  Arabic/English display name.
- [ ] Review Android permissions against the manifest and merged manifest.
  Notifications are opt-in; no exact-alarm permission is requested.
- [ ] Confirm that notification icons render correctly on supported Android
  versions and that users can disable each alert type.
- [ ] Decide how the owner will protect portable backups; this version does not
  encrypt `.hdb` files.
- [ ] Review privacy, data-retention, and app-store disclosures for locally
  stored customer/supplier data.

## Verification

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --release`
- [ ] Inspect APK size and verify package ID, version, app label, merged
  permissions, and signature (`apksigner verify --print-certs`).
- [ ] Install on a clean Android device/emulator; test first launch, Arabic/RTL,
  English, light/dark/system themes, notification permission denial/grant,
  offline sales/purchases, backup export, valid restore, and corrupted restore.
- [ ] Test backup restore against a copied production-like dataset and verify
  all expected records and balances before shipping.
- [ ] Store release APK, checksum, and signing metadata in the approved release
  system; keep the signing key outside the repository.

## Current build status

The checked-in Gradle release configuration uses the debug signing key so a
verification APK can be built without private credentials. Such an APK is not
production signed and must not be published. The package ID is still the
Flutter-template placeholder. No claim of production readiness is valid until
both are replaced and independently verified.
