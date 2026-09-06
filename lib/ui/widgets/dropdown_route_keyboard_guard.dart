import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Prevents a covered dropdown button from opening a second menu while keyboard
/// focus is still moving into the first menu's route.
///
/// The menu lives in its own route outside this focus subtree, so its normal
/// keyboard selection remains available. The guard adds no traversal stop.
class DropdownRouteKeyboardGuard extends StatelessWidget {
  const DropdownRouteKeyboardGuard({super.key, required this.child});

  final Widget child;

  static const _activationKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  ];

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: (_, event) {
      if (_activationKeys.contains(event.logicalKey) &&
          ModalRoute.of(context)?.isCurrent == false) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
