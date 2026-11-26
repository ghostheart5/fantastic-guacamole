import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two-part switch at the top of both Insights destinations:
/// "Future outcomes" and "Patterns".
///
/// [current] is the destination being shown. Choosing the other one opens it
/// inside the Insights tab. Patterns remembers that it was opened from Future
/// outcomes, so Back returns there.
class InsightsDestinationSwitch extends ConsumerWidget {
  const InsightsDestinationSwitch({required this.current, super.key})
    : assert(
        current == AppView.trajectoryEngine || current == AppView.progression,
      );

  /// [AppView.trajectoryEngine] (Future outcomes) or [AppView.progression]
  /// (Patterns).
  final AppView current;

  static const Key switchKey = Key('insights-destination-switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InsightsCopy copy = InsightsCopy.of(context);
    final bool onPatterns = current == AppView.progression;
    // The screens are dark pages that are not built with PlainScreen.
    return PlainPaletteScope(
      palette: PlainPalette.page,
      child: Semantics(
        container: true,
        label: copy.switchLabel,
        child: DestinationSwitch(
          key: switchKey,
          firstLabel: copy.futureOutcomes,
          secondLabel: copy.patterns,
          selectedIndex: onPatterns ? 1 : 0,
          onSelected: (int index) {
            if ((index == 1) == onPatterns) return;
            if (index == 1) {
              openActivityFrom(context, ref, AppView.trajectoryEngine);
            } else {
              goToAppView(context, ref, AppView.trajectoryEngine);
            }
          },
        ),
      ),
    );
  }
}
