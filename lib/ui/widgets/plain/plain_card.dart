import 'package:flutter/material.dart';

/// A Card with consistent padding. With [onTap] it is a button with a 48 dp
/// minimum target.
class PlainCard extends StatelessWidget {
  const PlainCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Label for screen readers when the card is tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget padded = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: onTap == null
          ? padded
          : Semantics(
              button: true,
              label: semanticLabel,
              container: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: padded,
              ),
            ),
    );
  }
}
