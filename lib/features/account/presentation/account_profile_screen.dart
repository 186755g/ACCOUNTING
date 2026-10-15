import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/backup_transport.dart';
import '../../../core/services/local_alert_service.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({
    required this.database,
    required this.initialSettings,
    required this.onSaved,
    required this.alerts,
    required this.onDatabaseRestored,
    super.key,
  });

  final LocalDatabase database;
  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSaved;
  final BusinessAlertService alerts;
  final Future<void> Function(LocalDatabase) onDatabaseRestored;

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _businessNameController = TextEditingController(
    text: widget.initialSettings.businessName,
  );
  late final _ownerNameController = TextEditingController(
    text: widget.initialSettings.ownerName,
  );
  late final _phoneController = TextEditingController(
    text: widget.initialSettings.phone,
  );
  late String _currencyCode = widget.initialSettings.currencyCode;
  late String _localeCode = widget.initialSettings.localeCode;
  late String _businessType = widget.initialSettings.businessType;
  late bool _allowNegativeStock = widget.initialSettings.allowNegativeStock;
  late bool _notifyLowStock = widget.initialSettings.notifyLowStock;
  late bool _notifyOutOfStock = widget.initialSettings.notifyOutOfStock;
  late bool _notifyUnpaidDebts = widget.initialSettings.notifyUnpaidDebts;
  late bool _notifyOverduePayments =
      widget.initialSettings.notifyOverduePayments;
  late bool _notifyDailySales = widget.initialSettings.notifyDailySales;
  bool _isSaving = false;
  bool _isBackingUp = false;
  bool _backupStatusFailed = false;
  File? _latestBackup;
  final BackupTransport _backupTransport = LocalBackupTransport();

  @override
  void initState() {
    super.initState();
    _loadLatestBackup();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final settings = widget.initialSettings.copyWith(
      businessName: _businessNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      currencyCode: _currencyCode,
      localeCode: _localeCode,
      businessType: _businessType,
      allowNegativeStock: _allowNegativeStock,
      notifyLowStock: _notifyLowStock,
      notifyOutOfStock: _notifyOutOfStock,
      notifyUnpaidDebts: _notifyUnpaidDebts,
      notifyOverduePayments: _notifyOverduePayments,
      notifyDailySales: _notifyDailySales,
    );
    try {
      await widget.database.settings.save(settings);
      if (!mounted) return;
      widget.onSaved(settings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Failed to save local account profile: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleAlert(bool value, ValueChanged<bool> update) async {
    if (!value) {
      setState(() => update(false));
      return;
    }
    try {
      final permitted = await widget.alerts.requestPermission();
      if (!mounted) return;
      if (!permitted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).notificationPermissionDenied,
            ),
          ),
        );
        return;
      }
      setState(() => update(true));
    } catch (error) {
      debugPrint(
        'Could not request local notification permission: ${error.runtimeType}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).notificationPermissionFailed,
          ),
        ),
      );
    }
  }

  Future<void> _loadLatestBackup() async {
    try {
      final latest = await BackupService().latestBackup();
      if (mounted) {
        setState(() {
          _latestBackup = latest;
          _backupStatusFailed = false;
        });
      }
    } catch (error) {
      debugPrint('Could not load latest local backup: ${error.runtimeType}');
      if (mounted) setState(() => _backupStatusFailed = true);
    }
  }

  Future<void> _createAndShareBackup() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);
    try {
      final strings = AppLocalizations.of(context);
      final file = await BackupService().createBackup(widget.database);
      if (!mounted) return;
      setState(() => _latestBackup = file);
      try {
        await _backupTransport.exportBackup(file, subject: strings.backupTitle);
      } catch (error) {
        debugPrint(
          'Backup was saved locally but could not be exported: ${error.runtimeType}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.backupExportFailed)));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.backupCreated)));
    } catch (error) {
      debugPrint(
        'Failed to create or export local backup: ${error.runtimeType}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).backupFailed)),
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _selectAndRestoreBackup() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);
    File? selectedBackup;
    try {
      selectedBackup = await _backupTransport.importBackup();
      if (selectedBackup == null) return;
      if (!mounted) return;
      final strings = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.restoreBackup),
          content: Text(strings.restoreBackupWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.restore),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final restored = await BackupService().restoreBackup(
        selectedBackup,
        widget.database,
      );
      await widget.onDatabaseRestored(restored);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DatabaseReplacementException catch (error) {
      await widget.onDatabaseRestored(error.recoveredDatabase);
      debugPrint('Backup restore was rolled back: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).restoreFailed)),
      );
      Navigator.of(context).pop();
    } on FormatException catch (error) {
      debugPrint('Rejected invalid local backup: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).backupInvalid)),
      );
    } catch (error) {
      debugPrint('Failed to restore local backup: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).restoreFailed)),
      );
    } finally {
      if (selectedBackup != null) {
        try {
          await _backupTransport.releaseImport(selectedBackup);
        } catch (error) {
          debugPrint(
            'Could not clean up imported backup temporary file: ${error.runtimeType}',
          );
        }
      }
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Directionality(
      textDirection: strings.isArabic
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(strings.profileTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    strings.offlineProfileNotice,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('business-name'),
                    controller: _businessNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: strings.businessName,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('owner-name'),
                    controller: _ownerNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: strings.ownerName),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('phone'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: strings.phone),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('business-type'),
                    initialValue: _businessType,
                    decoration: InputDecoration(
                      labelText: strings.businessType,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'retail',
                        child: Text(strings.retailBusiness),
                      ),
                      DropdownMenuItem(
                        value: 'grocery',
                        child: Text(strings.groceryBusiness),
                      ),
                      DropdownMenuItem(
                        value: 'restaurant',
                        child: Text(strings.restaurantBusiness),
                      ),
                      DropdownMenuItem(
                        value: 'services',
                        child: Text(strings.servicesBusiness),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(strings.otherBusiness),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _businessType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('currency'),
                    initialValue: _currencyCode,
                    decoration: InputDecoration(labelText: strings.currency),
                    items: [
                      DropdownMenuItem(
                        value: 'EGP',
                        child: Text('EGP — ${strings.egyptianPound}'),
                      ),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD — ${strings.usDollar}'),
                      ),
                      DropdownMenuItem(
                        value: 'EUR',
                        child: Text('EUR — ${strings.euro}'),
                      ),
                      DropdownMenuItem(
                        value: 'SAR',
                        child: Text('SAR — ${strings.saudiRiyal}'),
                      ),
                      DropdownMenuItem(
                        value: 'AED',
                        child: Text('AED — ${strings.uaeDirham}'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _currencyCode = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('language'),
                    initialValue: _localeCode,
                    decoration: InputDecoration(
                      labelText: strings.languageLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text(strings.arabicLanguage),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(strings.englishLanguage),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _localeCode = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey('allow-negative-stock'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.allowNegativeStock),
                    subtitle: Text(strings.allowNegativeStockDescription),
                    value: _allowNegativeStock,
                    onChanged: (value) =>
                        setState(() => _allowNegativeStock = value),
                  ),
                  const Divider(height: 32),
                  Text(
                    strings.notifications,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    key: const ValueKey('notify-low-stock'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.notifyLowStock),
                    value: _notifyLowStock,
                    onChanged: (value) =>
                        _toggleAlert(value, (next) => _notifyLowStock = next),
                  ),
                  SwitchListTile(
                    key: const ValueKey('notify-out-of-stock'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.notifyOutOfStock),
                    value: _notifyOutOfStock,
                    onChanged: (value) =>
                        _toggleAlert(value, (next) => _notifyOutOfStock = next),
                  ),
                  SwitchListTile(
                    key: const ValueKey('notify-unpaid-debts'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.notifyUnpaidDebts),
                    value: _notifyUnpaidDebts,
                    onChanged: (value) => _toggleAlert(
                      value,
                      (next) => _notifyUnpaidDebts = next,
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('notify-overdue-payments'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.notifyOverduePayments),
                    value: _notifyOverduePayments,
                    onChanged: (value) => _toggleAlert(
                      value,
                      (next) => _notifyOverduePayments = next,
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('notify-daily-sales'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.notifyDailySales),
                    subtitle: Text(strings.dailySalesNotificationTiming),
                    value: _notifyDailySales,
                    onChanged: (value) =>
                        _toggleAlert(value, (next) => _notifyDailySales = next),
                  ),
                  const Divider(height: 32),
                  Text(
                    strings.backupTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _backupStatusFailed
                        ? strings.backupStatusUnavailable
                        : _latestBackup == null
                        ? strings.noBackupCreated
                        : '${strings.latestBackup}: '
                              '${MaterialLocalizations.of(context).formatMediumDate(_latestBackup!.lastModifiedSync())}',
                  ),
                  Text(
                    strings.backupPrivacyNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isBackingUp ? null : _createAndShareBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(strings.createAndExportBackup),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isBackingUp ? null : _selectAndRestoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: Text(strings.restoreBackup),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(strings.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
