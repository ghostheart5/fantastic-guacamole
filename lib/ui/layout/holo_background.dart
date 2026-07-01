import 'package:flutter/material.dart';

import '../../theme/decorations.dart';

class HoloBackground extends StatelessWidget {
  final String? backgroundAsset;
  final Widget child;
  const HoloBackground({super.key, required this.child, this.backgroundAsset});

  @override
  Widget build(BuildContext context) {
    final bool hasAsset = backgroundAsset != null && backgroundAsset!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (hasAsset)
          Image.asset(
            backgroundAsset!,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                const ColoredBox(color: Color(0xFF000000)),
          )
        else
          Container(
            decoration: const BoxDecoration(gradient: AppDecorations.appBackground),
          ),
        child,
      ],
    );
  }
}
