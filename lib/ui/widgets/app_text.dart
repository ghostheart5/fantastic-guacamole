import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}
