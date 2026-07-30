import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

Future<T?> showPermissionRationaleSheet<T>({
  required BuildContext context,
  required PermissionExplainer explainer,
  required Future<void> Function() onPrimary,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: const Color(0xFF050D1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (BuildContext modalContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              explainer.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              explainer.whyItMatters,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              explainer.whenUsed,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await onPrimary();
                  if (modalContext.mounted) {
                    Navigator.of(modalContext).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neonCyan,
                  foregroundColor: Colors.black,
                ),
                child: Text(explainer.primaryActionLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  onSecondary?.call();
                  Navigator.of(modalContext).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.neonViolet.withValues(alpha: 0.5),
                  ),
                  foregroundColor: AppColors.neonViolet,
                ),
                child: Text(explainer.secondaryActionLabel),
              ),
            ),
          ],
        ),
      );
    },
  );
}
