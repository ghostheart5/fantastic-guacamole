import 'dart:async';

import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MicroTutorialCard extends ConsumerStatefulWidget {
  const MicroTutorialCard({
    super.key,
    required this.step,
    this.onComplete,
    this.onDismiss,
  });

  final TutorialStepContent step;
  final VoidCallback? onComplete;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<MicroTutorialCard> createState() => _MicroTutorialCardState();
}

class _MicroTutorialCardState extends ConsumerState<MicroTutorialCard> {
  String? _contextHint;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(tutorialProgressProvider.notifier).startTutorial());

      ref.read(tutorialAnalyticsProvider).trackCardViewed(widget.step.id);

      final String? hint = ref
          .read(tutorialProgressProvider.notifier)
          .showContextualHint(widget.step.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _contextHint = hint;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.24)),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.neonCyan.withValues(alpha: 0.10),
            AppColors.neonViolet.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            widget.step.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),

          if (_contextHint != null && _contextHint!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              _contextHint!,
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(tutorialProgressProvider.notifier)
                        .skipStep(widget.step.id);

                    widget.onDismiss?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.neonViolet.withValues(alpha: 0.40),
                    ),
                    foregroundColor: Colors.white70,
                    textStyle: const TextStyle(decoration: TextDecoration.none),
                  ),
                  child: const Text('Not Now'),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(tutorialProgressProvider.notifier)
                        .completeStep(widget.step.id);

                    widget.onComplete?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neonCyan,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(decoration: TextDecoration.none),
                  ),
                  child: Text(widget.step.ctaLabel),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await ref
                    .read(tutorialProgressProvider.notifier)
                    .skipStepForever(widget.step.id);

                widget.onDismiss?.call();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text(
                'Hide This Tip',
                style: TextStyle(decoration: TextDecoration.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
