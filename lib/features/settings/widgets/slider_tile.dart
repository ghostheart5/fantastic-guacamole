import 'package:flutter/material.dart';

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(title),
      Slider(value: value, onChanged: onChanged),
    ],
  );
}
