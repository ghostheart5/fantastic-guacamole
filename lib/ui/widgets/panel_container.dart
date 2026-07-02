import 'package:fantastic_guacamole/core/constants/app_sizes.dart';
import 'package:fantastic_guacamole/theme/theme.dart' hide NeonCard;
import 'package:fantastic_guacamole/ui/widgets/neon_card.dart';
import 'package:flutter/material.dart';

class PanelContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const PanelContainer({super.key, this.title = '', required this.child});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title.isNotEmpty) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSizes.sm),
              const NeonDivider(),
              const SizedBox(height: AppSizes.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
