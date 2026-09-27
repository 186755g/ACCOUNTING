import 'package:flutter/material.dart';

import 'app_card.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.name,
    required this.category,
    required this.price,
    required this.stockLabel,
    required this.icon,
    this.isLowStock = false,
    super.key,
  });

  final String name;
  final String category;
  final String price;
  final String stockLabel;
  final IconData icon;
  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stateColor = isLowStock ? colors.error : const Color(0xFF21866F);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(
                stockLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
