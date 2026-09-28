import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _searchController = TextEditingController();
  List<Category> _categories = [];
  List<Product> _products = [];
  String? _categoryId;
  ProductSortField _sortBy = ProductSortField.name;
  bool _lowStockOnly = false;
  bool _descending = false;
  bool _loading = true;
  String? _loadError;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final categories = await widget.database.categories.getAll(
        orderBy: 'name',
      );
      final products = await widget.database.products.browse(
        query: _searchController.text,
        categoryId: _categoryId,
        lowStockOnly: _lowStockOnly,
        sortBy: _sortBy,
        descending: _descending,
      );
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _categories = categories;
        _products = products;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      debugPrint('Failed to load products: $error');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _openProduct([Product? product, bool duplicate = false]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        database: widget.database,
        categories: _categories,
        product: product,
        duplicate: duplicate,
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).productSaved)),
        );
      }
    }
  }

  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CategoryManagementScreen(database: widget.database),
      ),
    );
    await _load();
  }

  Future<void> _deleteProduct(Product product) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(strings.confirmDeleteProduct),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.database.products.delete(product.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _sortLabel(AppLocalizations strings) => switch (_sortBy) {
    ProductSortField.name => strings.sortName,
    ProductSortField.stock => strings.sortStock,
    ProductSortField.purchasePrice => strings.sortPurchasePrice,
    ProductSortField.sellingPrice => strings.sortSellingPrice,
    ProductSortField.createdDate => strings.sortCreatedDate,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.productsTitle),
        actions: [
          IconButton(
            key: const ValueKey('manage-categories'),
            tooltip: strings.categoriesTitle,
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-product'),
        onPressed: () => _openProduct(),
        icon: const Icon(Icons.add),
        label: Text(strings.addProduct),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('product-search'),
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: strings.searchProducts,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: strings.categoriesTitle,
                  onPressed: _openCategories,
                  icon: const Icon(Icons.category_outlined),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  key: const ValueKey('category-filter'),
                  value: _categoryId,
                  hint: Text(strings.allCategories),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.allCategories),
                    ),
                    ..._categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryId = value);
                    _load();
                  },
                ),
                FilterChip(
                  key: const ValueKey('low-stock-filter'),
                  label: Text(strings.lowStockOnly),
                  selected: _lowStockOnly,
                  onSelected: (value) {
                    setState(() => _lowStockOnly = value);
                    _load();
                  },
                ),
                PopupMenuButton<ProductSortField>(
                  key: const ValueKey('product-sort'),
                  tooltip: strings.sortBy,
                  initialValue: _sortBy,
                  onSelected: (value) {
                    setState(() => _sortBy = value);
                    _load();
                  },
                  itemBuilder: (context) => [
                    _sortItem(ProductSortField.name, strings.sortName),
                    _sortItem(ProductSortField.stock, strings.sortStock),
                    _sortItem(
                      ProductSortField.purchasePrice,
                      strings.sortPurchasePrice,
                    ),
                    _sortItem(
                      ProductSortField.sellingPrice,
                      strings.sortSellingPrice,
                    ),
                    _sortItem(
                      ProductSortField.createdDate,
                      strings.sortCreatedDate,
                    ),
                  ],
                  child: Chip(
                    label: Text('${strings.sortBy}: ${_sortLabel(strings)}'),
                    avatar: const Icon(Icons.sort),
                  ),
                ),
                IconButton(
                  key: const ValueKey('sort-direction'),
                  tooltip: _descending ? strings.descending : strings.ascending,
                  onPressed: () {
                    setState(() => _descending = !_descending);
                    _load();
                  },
                  icon: Icon(
                    _descending ? Icons.south_rounded : Icons.north_rounded,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          child: Text(strings.retry),
                        ),
                      ],
                    ),
                  )
                : _products.isEmpty
                ? Center(child: Text(strings.noProducts))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final category = _categories
                            .where((value) => value.id == product.categoryId)
                            .firstOrNull;
                        return _ProductCard(
                          product: product,
                          categoryName: category?.name,
                          onEdit: () => _openProduct(product),
                          onDuplicate: () => _openProduct(product, true),
                          onDelete: () => _deleteProduct(product),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ProductSortField> _sortItem(
    ProductSortField value,
    String label,
  ) => PopupMenuItem(value: value, child: Text(label));
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Product product;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final lowStock = product.stockQuantity <= product.minimumStock;
    return Card(
      key: ValueKey('product-card-${product.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(
          start: 14,
          end: 4,
          top: 4,
          bottom: 4,
        ),
        leading: _ProductImage(imagePath: product.imagePath),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (categoryName != null) categoryName,
                if (product.sku?.isNotEmpty == true) 'SKU: ${product.sku}',
                if (product.barcode?.isNotEmpty == true)
                  '${strings.barcode}: ${product.barcode}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${strings.stockQuantity}: ${product.stockQuantity} ${product.unit}'
              ' · ${strings.purchasePrice}: ${_money(product.costPriceMinor)}'
              ' · ${strings.sellingPrice}: ${_money(product.sellingPriceMinor)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: lowStock
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${strings.createdDate}: ${product.createdAt.toLocal().toString().split(' ').first}'
              ' · ${strings.updatedDate}: ${product.updatedAt.toLocal().toString().split(' ').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (!product.isActive)
              Text(
                strings.inactive,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: strings.manageProducts,
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'duplicate') onDuplicate();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(strings.editProduct)),
            PopupMenuItem(
              value: 'duplicate',
              child: Text(strings.duplicateProduct),
            ),
            PopupMenuItem(value: 'delete', child: Text(strings.delete)),
          ],
        ),
      ),
    );
  }

  String _money(int minor) => (minor / 100).toStringAsFixed(2);
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imagePath!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const CircleAvatar(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.database,
    required this.categories,
    this.product,
    this.duplicate = false,
  });

  final LocalDatabase database;
  final List<Category> categories;
  final Product? product;
  final bool duplicate;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.duplicate && widget.product != null
        ? '${widget.product!.name} (2)'
        : widget.product?.name ?? '',
  );
  late final _sku = TextEditingController(
    text: widget.duplicate ? '' : widget.product?.sku ?? '',
  );
  late final _barcode = TextEditingController(
    text: widget.duplicate ? '' : widget.product?.barcode ?? '',
  );
  late final _purchasePrice = TextEditingController(
    text: widget.product == null
        ? ''
        : (widget.product!.costPriceMinor / 100).toStringAsFixed(2),
  );
  late final _sellingPrice = TextEditingController(
    text: widget.product == null
        ? ''
        : (widget.product!.sellingPriceMinor / 100).toStringAsFixed(2),
  );
  late final _stock = TextEditingController(
    text: widget.product?.stockQuantity.toString() ?? '0',
  );
  late final _minimumStock = TextEditingController(
    text: widget.product?.minimumStock.toString() ?? '0',
  );
  late final _unit = TextEditingController(
    text: widget.product?.unit ?? 'piece',
  );
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _imagePath = TextEditingController(
    text: widget.product?.imagePath ?? '',
  );
  late String? _categoryId = widget.product?.categoryId;
  late bool _isActive = widget.duplicate
      ? true
      : widget.product?.isActive ?? true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _barcode,
      _purchasePrice,
      _sellingPrice,
      _stock,
      _minimumStock,
      _unit,
      _description,
      _imagePath,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? AppLocalizations.of(context).requiredField
      : null;

  String? _number(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return AppLocalizations.of(context).invalidNumber;
    }
    if (parsed < 0) return AppLocalizations.of(context).invalidNonNegative;
    return null;
  }

  int _minorUnits(String value) => (double.parse(value.trim()) * 100).round();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now().toUtc();
    final original = widget.product;
    final product = Product(
      id: widget.duplicate ? null : original?.id,
      categoryId: _categoryId,
      sku: _emptyToNull(_sku.text),
      barcode: _emptyToNull(_barcode.text),
      name: _name.text.trim(),
      costPriceMinor: _minorUnits(_purchasePrice.text),
      sellingPriceMinor: _minorUnits(_sellingPrice.text),
      stockQuantity: widget.product != null && !widget.duplicate
          ? widget.product!.stockQuantity
          : double.parse(_stock.text.trim()),
      minimumStock: double.parse(_minimumStock.text.trim()),
      unit: _unit.text.trim(),
      description: _emptyToNull(_description.text),
      imagePath: _emptyToNull(_imagePath.text),
      isActive: _isActive,
      createdAt: widget.duplicate ? now : original?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      if (original != null && !widget.duplicate) {
        await widget.database.products.update(product);
      } else {
        await widget.database.products.create(product);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().contains('UNIQUE constraint failed')
            ? AppLocalizations.of(context).duplicateValueError
            : error.toString();
      });
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    Key? key,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final title = widget.product == null
        ? strings.addProduct
        : widget.duplicate
        ? strings.duplicateProduct
        : strings.editProduct;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  _name,
                  strings.productName,
                  key: const ValueKey('product-name'),
                  validator: _required,
                ),
                _field(_sku, strings.sku, key: const ValueKey('product-sku')),
                _field(
                  _barcode,
                  strings.barcode,
                  key: const ValueKey('product-barcode'),
                ),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('product-category'),
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: strings.selectCategory,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.noCategory),
                    ),
                    ...widget.categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                _field(
                  _purchasePrice,
                  strings.purchasePrice,
                  key: const ValueKey('product-purchase-price'),
                  validator: _number,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _field(
                  _sellingPrice,
                  strings.sellingPrice,
                  key: const ValueKey('product-selling-price'),
                  validator: _number,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (widget.product == null || widget.duplicate)
                  _field(
                    _stock,
                    strings.stockQuantity,
                    key: const ValueKey('product-stock'),
                    validator: _number,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                _field(
                  _minimumStock,
                  strings.minimumStock,
                  key: const ValueKey('product-minimum-stock'),
                  validator: _number,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _field(
                  _unit,
                  strings.unit,
                  key: const ValueKey('product-unit'),
                  validator: _required,
                ),
                _field(
                  _description,
                  strings.description,
                  key: const ValueKey('product-description'),
                  maxLines: 2,
                ),
                _field(
                  _imagePath,
                  strings.productImagePath,
                  key: const ValueKey('product-image-path'),
                  keyboardType: TextInputType.url,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.activeProduct),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.save),
        ),
      ],
    );
  }
}

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await widget.database.categories.getAll(orderBy: 'name');
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _edit([Category? category]) async {
    final strings = AppLocalizations.of(context);
    final controller = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(
      text: category?.description ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          category == null ? strings.addCategory : strings.editCategory,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(labelText: strings.categoryName),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.requiredField
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: strings.description),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, (
                  controller.text.trim(),
                  descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                ));
              }
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    descriptionController.dispose();
    if (result == null) return;
    final now = DateTime.now().toUtc();
    final edited = Category(
      id: category?.id,
      name: result.$1,
      description: result.$2,
      createdAt: category?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      if (category == null) {
        await widget.database.categories.create(edited);
      } else {
        await widget.database.categories.update(edited);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('UNIQUE constraint failed')
                ? strings.duplicateCategoryError
                : error.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _delete(Category category) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(strings.confirmDeleteCategory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.database.categories.delete(category.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-category'),
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: Text(strings.addCategory),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? Center(child: Text(strings.noCategories))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  child: ListTile(
                    key: ValueKey('category-${category.id}'),
                    title: Text(category.name),
                    subtitle: category.description == null
                        ? null
                        : Text(category.description!),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: strings.editCategory,
                          onPressed: () => _edit(category),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: strings.delete,
                          onPressed: () => _delete(category),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
