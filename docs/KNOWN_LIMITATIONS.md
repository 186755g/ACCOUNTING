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
- Product browsing is paginated; some histories and party/report filter
  selectors still use bounded or unpaged reads and may need further tuning for
  very large businesses.
- Notification presentation, receipt printing, file sharing, and file picking
  depend on their host-platform integrations and require device-level testing.
- No clean-device Android install, store listing, production signature, or
  store compliance review can be asserted until release credentials and the
  final package identity are supplied.
