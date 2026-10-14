import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/database/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.open();
  final installationId = await database.installationIdentity.getOrCreateSafe();
  if (installationId == null) {
    debugPrint(
      'Installation identity unavailable; continuing in local-only mode.',
    );
  }
  final settings = await database.settings.get();
  if (settings == null) {
    throw StateError('Local app settings were not initialized.');
  }
  runApp(HesabatiApp(database: database, initialSettings: settings));
}
