import 'package:flutter/material.dart';

/// Owns text controllers for the lifetime of a dialog or sheet's widget tree.
///
/// A route's pop future can finish before its exit transition and fields have
/// unmounted. Keep disposal here instead of after awaiting the route result.
/// [initialTexts] is read once on mount; rebuilds preserve the user's draft.
class TextControllerScope extends StatefulWidget {
  const TextControllerScope({
    super.key,
    this.initialTexts = const <String>[''],
    required this.builder,
  }) : assert(initialTexts.length > 0);

  final List<String> initialTexts;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  )
  builder;

  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  late final List<TextEditingController> _controllers =
      List<TextEditingController>.unmodifiable(
        widget.initialTexts.map((text) => TextEditingController(text: text)),
      );

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
