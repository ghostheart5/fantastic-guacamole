import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.asset, {this.size = 24, this.color, super.key});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color resolvedColor = color ?? Theme.of(context).colorScheme.primary;

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
