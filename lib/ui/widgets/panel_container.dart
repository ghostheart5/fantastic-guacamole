import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import 'neon_card.dart';

class PanelContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const PanelContainer({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.sm),
            child,
          ],
        ),
      ),
    );
  }
}
