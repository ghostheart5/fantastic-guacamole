import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:flutter/material.dart';

/// One step of the first-run guide, shown in the same small, non-blocking
/// place as a contextual hint (`GuideHintSlot`). Unlike a hint it stays until
/// its step is done, skipped or the guide is paused: it shows the step
/// number, the instruction, the step's action, "Skip this step" and "Pause
/// guide", and optionally "Back".
///
/// It adds no barrier and never takes keyboard input away from the page, so
/// the page, the navigation and Settings stay usable. When space is short, text and buttons scroll inside
/// the card. Callers pass already translated strings.
class GuideStepCard extends StatelessWidget {
  const GuideStepCard({
    required this.progressLabel,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.skipStepLabel,
    required this.onSkipStep,
    required this.pauseLabel,
    required this.onPause,
    this.primaryEnabled = true,
    this.backLabel,
    this.onBack,
    super.key,
  }) : assert(
         (backLabel == null) == (onBack == null),
         'Back needs both a label and a callback.',
       );

  /// For example "Step 1 of 2".
  final String progressLabel;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final String skipStepLabel;
  final VoidCallback onSkipStep;
  final String pauseLabel;
  final VoidCallback onPause;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Exactly 48 dp tall for one line of text, so the buttons still fit the
    // small card at large text sizes.
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 4,
    );
    final ButtonStyle textStyle = TextButton.styleFrom(
      foregroundColor: AppColors.neonCyan,
      minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      padding: buttonPadding,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final BorderRadius radius = BorderRadius.circular(8);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '$progressLabel. $title',
      child: Material(
        color: const Color(0xFF08131F),
        elevation: 6,
        shadowColor: AppColors.neonCyan.withValues(alpha: .25),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: .72),
            ),
          ),
          // Text and buttons scroll together when the card is short of
          // space (large text, narrow screens), so nothing is cut off.
          child: SingleChildScrollView(
            key: const Key('guide_step_content'),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Already part of the card's announcement.
                      ExcludeSemantics(
                        child: Text(
                          progressLabel,
                          style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ExcludeSemantics(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  // Stacked on narrow screens or large text, the step's
                  // action stays on top.
                  overflowDirection: VerticalDirection.up,
                  spacing: 4,
                  overflowSpacing: 4,
                  children: <Widget>[
                    if (backLabel case final String back)
                      TextButton(
                        key: const Key('guide_step_back'),
                        style: textStyle,
                        onPressed: onBack,
                        child: Text(back, textAlign: TextAlign.center),
                      ),
                    TextButton(
                      key: const Key('guide_step_pause'),
                      style: textStyle,
                      onPressed: onPause,
                      child: Text(pauseLabel, textAlign: TextAlign.center),
                    ),
                    TextButton(
                      key: const Key('guide_step_skip'),
                      style: textStyle,
                      onPressed: onSkipStep,
                      child: Text(skipStepLabel, textAlign: TextAlign.center),
                    ),
                    FilledButton(
                      key: const Key('guide_step_primary'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          AppSizes.touchTarget,
                          AppSizes.touchTarget,
                        ),
                        padding: buttonPadding,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: primaryEnabled ? onPrimary : null,
                      child: Text(primaryLabel, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
