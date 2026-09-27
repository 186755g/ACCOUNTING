import 'package:flutter/material.dart';

import 'app_card.dart';

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    required this.name,
    required this.subtitle,
    required this.amount,
    this.initials,
    this.hasBalance = false,
    super.key,
  });

  final String name;
  final String subtitle;
  final String amount;
  final String? initials;
  final bool hasBalance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            foregroundColor: colors.primary,
            child: Text(
              initials ?? _firstCharacter(name),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: hasBalance ? colors.error : colors.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  String _firstCharacter(String value) =>
      value.isEmpty ? '?' : String.fromCharCode(value.runes.first);
}
