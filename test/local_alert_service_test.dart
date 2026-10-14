import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:hesabati/core/services/local_alert_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase database;
  late _RecordingNotifications notifications;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await LocalDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    notifications = _RecordingNotifications();
  });

  tearDown(() => database.close());

  test(
    'deduplicates alert delivery and resets after a resolved condition',
    () async {
      await database.settings.save(
        (await database.settings.get())!.copyWith(notifyLowStock: true),
      );
      final product = Product(
        id: 'notification-stock',
        name: 'Notification stock',
        costPriceMinor: 20,
        sellingPriceMinor: 30,
        stockQuantity: 2,
        minimumStock: 3,
      );
      await database.products.create(product);
      final alerts = LocalAlertService(
        database,
        notificationClient: notifications,
      );
      final now = DateTime(2026, 7, 1, 10);

      await alerts.refresh(now: now);
      await alerts.refresh(now: now.add(const Duration(minutes: 1)));
      expect(notifications.messages, hasLength(1));

      await database.products.update(
        Product(
          id: product.id,
          name: product.name,
          costPriceMinor: product.costPriceMinor,
          sellingPriceMinor: product.sellingPriceMinor,
          stockQuantity: 5,
          minimumStock: 3,
        ),
      );
      await alerts.refresh(now: now.add(const Duration(minutes: 2)));
      expect(
        await database.transaction(
          (transaction) => transaction.query('notification_deliveries'),
        ),
        isEmpty,
      );

      await database.products.update(
        Product(
          id: product.id,
          name: product.name,
          costPriceMinor: product.costPriceMinor,
          sellingPriceMinor: product.sellingPriceMinor,
          stockQuantity: 2,
          minimumStock: 3,
        ),
      );
      await alerts.refresh(now: now.add(const Duration(minutes: 3)));
      expect(notifications.messages, hasLength(2));
    },
  );
}

class _RecordingNotifications implements LocalNotificationClient {
  final messages = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    messages.add('$id:$title:$body');
  }
}
