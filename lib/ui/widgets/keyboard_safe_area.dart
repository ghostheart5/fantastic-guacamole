import 'package:flutter/widgets.dart';

/// Formalizes the keyboard-inset pattern already used correctly by the
/// Goals/Memories/Milestones/Personal Alignment bottom-sheet editors (each hand-derives
/// `MediaQuery.of(ctx).viewInsets.bottom` itself) so new call sites read the
/// inset and visibility together instead of re-deriving both.
class KeyboardSafeArea extends StatelessWidget {
  const KeyboardSafeArea({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    double keyboardInset,
    bool keyboardVisible,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return builder(context, keyboardInset, keyboardInset > 0);
  }
}
