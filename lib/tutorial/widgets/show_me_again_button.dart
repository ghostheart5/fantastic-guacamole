import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShowMeAgainButton extends ConsumerWidget {
  const ShowMeAgainButton({super.key, required this.stepId, this.label = 'Show Me Again'});

  final String stepId;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: TextButton(
            onPressed: () async {
              await ref.read(tutorialProgressProvider.notifier).showAgain(stepId);

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tutorial tip re-enabled for this screen.')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neonCyan,
              textStyle: const TextStyle(decoration: TextDecoration.none),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 16),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
