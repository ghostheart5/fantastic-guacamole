import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:flutter/material.dart';

/// A small hint that does not block the screen: a short label, a title, a
/// plain explanation, a dismiss button and at most one action.
///
/// It adds no barrier and never takes keyboard input away from the page, so
/// everything around it stays usable. Screen readers hear it once, as "label. title", when it appears.
/// When space is short (large text, narrow screens) the text scrolls inside
/// the card and both buttons stay on screen. Callers pass already translated
/// strings.
class GuideHintCard extends StatelessWidget {
  const GuideHintCard({
    required this.label,
    required this.title,
    required this.body,
    required this.dismissLabel,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  /// Names the kind of hint, for example "Help with this page".
  final String label;
  final String title;
  final String body;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.neonCyan,
      minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    final BorderRadius radius = BorderRadius.circular(8);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '$label. $title',
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('guide_hint_text'),
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Already part of the card's announcement.
                        ExcludeSemantics(
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 16,
                                color: AppColors.memoryAmber,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: AppColors.neonCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
                ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 4,
                  children: <Widget>[
                    TextButton(
                      key: const Key('guide_hint_dismiss'),
                      style: buttonStyle,
                      onPressed: onDismiss,
                      child: Text(dismissLabel, textAlign: TextAlign.center),
                    ),
                    if (actionLabel case final String action)
                      TextButton(
                        key: const Key('guide_hint_action'),
                        style: buttonStyle,
                        onPressed: onAction,
                        child: Text(action, textAlign: TextAlign.center),
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
