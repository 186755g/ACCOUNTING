import 'package:flutter/material.dart';

import 'app_button.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final Widget content;
  final AppDialogAction? primaryAction;
  final AppDialogAction? secondaryAction;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    AppDialogAction? primaryAction,
    AppDialogAction? secondaryAction,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: content,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        if (secondaryAction case final action?)
          AppButton(
            label: action.label,
            variant: AppButtonVariant.text,
            onPressed: action.onPressed,
          ),
        if (primaryAction case final action?)
          AppButton(
            label: action.label,
            onPressed: action.onPressed,
            variant: action.isDestructive
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
          ),
      ],
    );
  }
}

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
}
