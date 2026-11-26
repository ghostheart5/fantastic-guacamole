import 'package:flutter/material.dart';

/// Block that is collapsed by default (or open with [initiallyExpanded]). The
/// title row toggles the children and tells screen readers whether it is
/// expanded or collapsed. The open state lives in this widget, so give it a
/// stable key where its parent can reorder or rebuild it with a new identity.
class PlainDisclosure extends StatefulWidget {
  const PlainDisclosure({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<PlainDisclosure> createState() => _PlainDisclosureState();
}

class _PlainDisclosureState extends State<PlainDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.title,
          excludeSemantics: true,
          onTap: _toggle,
          child: InkWell(
            onTap: _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}
