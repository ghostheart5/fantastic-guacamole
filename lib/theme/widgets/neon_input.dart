import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/theme/shadows.dart';
import 'package:fantastic_guacamole/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class NeonInput extends StatefulWidget {
  const NeonInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  State<NeonInput> createState() => _NeonInputState();
}

class _NeonInputState extends State<NeonInput> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NeonInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final NeonEffects effects =
        Theme.of(context).extension<NeonEffects>() ?? defaultNeonEffects;
    final bool isFocused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: inputRadius,
        boxShadow: isFocused ? neonGlowCyan : const <BoxShadow>[],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(
              color: hologramWhite.withValues(alpha: effects.hologramOpacity),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(
              color: neonCyan.withValues(alpha: 0.9),
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
