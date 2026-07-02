import 'package:flutter/material.dart';

class ToggleTile extends StatefulWidget {
  const ToggleTile({
    required this.title,
    required this.value,
    this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<ToggleTile> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled = widget.value;
  }

  @override
  void didUpdateWidget(covariant ToggleTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      enabled = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.title),
      value: enabled,
      onChanged: (value) {
        setState(() {
          enabled = value;
        });
        widget.onChanged?.call(value);
      },
    );
  }
}
