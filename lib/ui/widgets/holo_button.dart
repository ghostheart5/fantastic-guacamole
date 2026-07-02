import 'package:fantastic_guacamole/theme/theme.dart' as neon;
import 'package:flutter/material.dart';

class HoloButton extends StatefulWidget {
  const HoloButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<HoloButton> createState() => _HoloButtonState();
}

class _HoloButtonState extends State<HoloButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Color get _color => widget.color ?? neon.neonCyan;

  void _onTapDown(TapDownDetails _) => _press.forward();
  void _onTapUp(TapUpDetails _) {
    _press.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, _) => Transform.scale(
              scale: _scale.value,
              child: SizedBox(
                width: double.infinity,
                child: neon.NeonButton(
                  label: widget.label.toUpperCase(),
                  accentColor: _color,
                  onPressed: widget.onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
