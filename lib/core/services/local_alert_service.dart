import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../database/models/model_utils.dart';
import 'financial_service.dart';

abstract interface class BusinessAlertService {
  Future<void> refresh({DateTime? now});

  Future<bool> requestPermission();
}

abstract interface class LocalNotificationScheduler {
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancel(int id);
}

abstract interface class LocalNotificationClient {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

class FlutterLocalNotificationClient implements LocalNotificationClient {
  FlutterLocalNotificationClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open Hesabati'),
        windows: WindowsInitializationSettings(
          appName: 'Hesabati',
          appUserModelId: 'com.hesabati.business',
          guid: 'f1591974-5943-4dc8-b462-7bcb4259c137',
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    if (Platform.isMacOS) {
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await mac?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'business_alerts',
        'Business alerts',
        channelDescription: 'Opt-in alerts about local business activity.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    ),
  );
}

class LocalAlertService implements BusinessAlertService {
  LocalAlertService(
    this._database, {
    LocalNotificationClient? notificationClient,
    this.scheduler,
  }) : _notificationClient =
           notificationClient ?? FlutterLocalNotificationClient();

  final LocalDatabase _database;
  final LocalNotificationClient _notificationClient;
  final LocalNotificationScheduler? scheduler;

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) {
    final schedulerPort = scheduler;
    if (schedulerPort == null) {
      throw StateError('No background notification scheduler is configured.');
    }
    return schedulerPort.schedule(id: id, title: title, body: body, at: at);
  }

  Future<void> cancelScheduled(int id) {
    final schedulerPort = scheduler;
    if (schedulerPort == null) {
      throw StateError('No background notification scheduler is configured.');
    }
    return schedulerPort.cancel(id);
  }

  Future<void> initialize() => _notificationClient.initialize();

  @override
  Future<bool> requestPermission() => _notificationClient.requestPermission();

  @override
  Future<void> refresh({DateTime? now}) async {
    await initialize();
    final settings = await _database.settings.get();
    if (settings == null) {
      throw StateError('Local app settings were not initialized.');
    }
    if (!settings.notifyLowStock &&
        !settings.notifyOutOfStock &&
        !settings.notifyUnpaidDebts &&
        !settings.notifyOverduePayments &&
        !settings.notifyDailySales) {
      await _database.transaction(
        (transaction) => transaction.delete('notification_deliveries'),
      );
      return;
    }

    final clock = now ?? DateTime.now();
    final metrics = await FinancialService(_database)
        .getNotificationMetrics(now: clock);
    final alerts = <_Alert>[];
    if (settings.notifyOutOfStock && metrics.outOfStockCount > 0) {
      alerts.add(
        _Alert(
          key: 'out-of-stock',
          id: 1,
          fingerprint: '${metrics.outOfStockCount}',
          title: settings.localeCode == 'ar' ? 'نفد المخزون' : 'Out of stock',
          body: settings.localeCode == 'ar'
              ? 'عدد المنتجات التي نفد مخزونها: ${metrics.outOfStockCount}'
              : '${metrics.outOfStockCount} products are out of stock.',
        ),
      );
    }
    if (settings.notifyLowStock && metrics.lowStockCount > 0) {
      alerts.add(
        _Alert(
          key: 'low-stock',
          id: 2,
          fingerprint: '${metrics.lowStockCount}',
          title: settings.localeCode == 'ar' ? 'مخزون منخفض' : 'Low stock',
          body: settings.localeCode == 'ar'
              ? 'عدد المنتجات منخفضة المخزون: ${metrics.lowStockCount}'
              : '${metrics.lowStockCount} products are below their stock level.',
        ),
      );
    }
    if (settings.notifyUnpaidDebts &&
        (metrics.unpaidCustomerCount > 0 || metrics.unpaidSupplierCount > 0)) {
      alerts.add(
        _Alert(
          key: 'unpaid-party-debts',
          id: 3,
          fingerprint:
              '${metrics.unpaidCustomerCount}:${metrics.unpaidSupplierCount}',
          title: settings.localeCode == 'ar'
              ? 'أرصدة غير مسددة'
              : 'Unpaid balances',
          body: settings.localeCode == 'ar'
              ? 'عملاء: ${metrics.unpaidCustomerCount}، موردون: ${metrics.unpaidSupplierCount}.'
              : 'Customers: ${metrics.unpaidCustomerCount}; suppliers: ${metrics.unpaidSupplierCount}.',
        ),
      );
    }
    if (settings.notifyOverduePayments &&
        (metrics.overdueCustomerCount > 0 ||
            metrics.overdueSupplierCount > 0)) {
      alerts.add(
        _Alert(
          key: 'overdue-party-payments',
          id: 4,
          fingerprint:
              '${metrics.overdueCustomerCount}:${metrics.overdueSupplierCount}',
          title: settings.localeCode == 'ar'
              ? 'مدفوعات متأخرة'
              : 'Overdue payments',
          body: settings.localeCode == 'ar'
              ? 'عملاء: ${metrics.overdueCustomerCount}، موردون: ${metrics.overdueSupplierCount}.'
              : 'Customers: ${metrics.overdueCustomerCount}; suppliers: ${metrics.overdueSupplierCount}.',
        ),
      );
    }
    if (settings.notifyDailySales && metrics.previousDaySalesMinor >= 0) {
      final previousDay = DateTime(
        clock.year,
        clock.month,
        clock.day,
      ).subtract(const Duration(days: 1));
      final dateKey =
          '${previousDay.year}-${previousDay.month.toString().padLeft(2, '0')}-${previousDay.day.toString().padLeft(2, '0')}';
      final sales = (metrics.previousDaySalesMinor / 100).toStringAsFixed(2);
      alerts.add(
        _Alert(
          key: 'daily-sales',
          id: 5,
          fingerprint: dateKey,
          title: settings.localeCode == 'ar'
              ? 'ملخص المبيعات اليومي'
              : 'Daily sales summary',
          body: settings.localeCode == 'ar'
              ? 'مبيعات الأمس: $sales ${settings.currencyCode}'
              : 'Yesterday’s sales: $sales ${settings.currencyCode}',
        ),
      );
    }

    final activeKeys = alerts.map((alert) => alert.key).toSet();
    final enabledKeys = {
      if (settings.notifyLowStock) 'low-stock',
      if (settings.notifyOutOfStock) 'out-of-stock',
      if (settings.notifyUnpaidDebts) 'unpaid-party-debts',
      if (settings.notifyOverduePayments) 'overdue-party-payments',
      if (settings.notifyDailySales) 'daily-sales',
    };
    for (final resolvedKey in enabledKeys.difference(activeKeys)) {
      await _database.transaction(
        (transaction) => transaction.delete(
          'notification_deliveries',
          where: 'alert_key = ?',
          whereArgs: [resolvedKey],
        ),
      );
    }

    for (final alert in alerts) {
      await _deliverIfChanged(alert, clock);
    }
  }

  Future<void> _deliverIfChanged(_Alert alert, DateTime now) async {
    final deliveries = await _database.transaction(
      (transaction) => transaction.query(
        'notification_deliveries',
        columns: ['fingerprint', 'delivered_at'],
        where: 'alert_key = ?',
        whereArgs: [alert.key],
        limit: 1,
      ),
    );
    if (deliveries.isNotEmpty) {
      final prior = deliveries.single;
      final deliveredAt = dateFromDatabase(prior['delivered_at']);
      if (prior['fingerprint'] == alert.fingerprint ||
          now.difference(deliveredAt) < const Duration(hours: 6)) {
        return;
      }
    }

    await _notificationClient.show(
      id: alert.id,
      title: alert.title,
      body: alert.body,
    );
    await _database.transaction((transaction) async {
      await transaction.insert('notification_deliveries', {
        'alert_key': alert.key,
        'fingerprint': alert.fingerprint,
        'delivered_at': dateToDatabase(now),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

class _Alert {
  const _Alert({
    required this.key,
    required this.id,
    required this.fingerprint,
    required this.title,
    required this.body,
  });

  final String key;
  final int id;
  final String fingerprint;
  final String title;
  final String body;
}
