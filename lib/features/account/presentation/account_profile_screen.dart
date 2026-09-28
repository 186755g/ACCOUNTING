import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({
    required this.database,
    required this.initialSettings,
    required this.onSaved,
    super.key,
  });

  final LocalDatabase database;
  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSaved;

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
  bool _isSaving = false;

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
      debugPrint('Failed to save local account profile: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Directionality(
      textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
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
