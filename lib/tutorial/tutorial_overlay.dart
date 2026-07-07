// lib/tutorial/tutorial_overlay.dart

import 'dart:math' as math;

import 'package:fantastic_guacamole/tutorial/tutorial_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:flutter/material.dart';

class TutorialHost extends StatefulWidget {
  const TutorialHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final TutorialController controller;
  final Widget child;

  @override
  State<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends State<TutorialHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.activeStep;

    return Stack(
      children: <Widget>[
        widget.child,
        if (widget.controller.running && step != null)
          _TutorialOverlay(step: step, controller: widget.controller),
      ],
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({required this.step, required this.controller});

  final TutorialStep step;
  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    final Rect? target = step.targetId == null
        ? null
        : TutorialTargetRegistry.instance.rectFor(step.targetId!);

    final bool nonBlocking = step.blockMode == TutorialBlockMode.nonBlocking;

    return IgnorePointer(
      ignoring: nonBlocking,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (target != null && target.contains(details.globalPosition)) {
                  controller.reportEvent('tap:${step.targetId}');
                }
              },
              onLongPressStart: (details) {
                if (target != null && target.contains(details.globalPosition)) {
                  controller.reportEvent('longPress:${step.targetId}');
                }
              },
              child: CustomPaint(painter: _TutorialPainter(target: target)),
            ),
          ),
          _TooltipCard(step: step, target: target, controller: controller),
        ],
      ),
    );
  }
}

class _TutorialPainter extends CustomPainter {
  const _TutorialPainter({required this.target});

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dim = Paint()..color = Colors.black.withValues(alpha: 0.68);
    final Path full = Path()..addRect(Offset.zero & size);

    if (target == null) {
      canvas.drawPath(full, dim);
      return;
    }

    final Rect hole = target!.inflate(8);
    final Path cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));

    canvas.drawPath(Path.combine(PathOperation.difference, full, cutout), dim);

    final Paint border = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(16)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialPainter oldDelegate) {
    return oldDelegate.target != target;
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.step,
    required this.target,
    required this.controller,
  });

  final TutorialStep step;
  final Rect? target;
  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double width = math.min(screen.width - 32, 360);

    double top = 96;
    double left = 16;

    if (target != null) {
      top = target!.bottom + 18;
      if (top + 220 > screen.height) top = target!.top - 220;
      top = top.clamp(24, screen.height - 240);
      left = (target!.center.dx - width / 2).clamp(
        16,
        screen.width - width - 16,
      );
    }

    return Positioned(
      top: top,
      left: left,
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(step.body),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: controller.pause,
                        child: const Text('Pause'),
                      ),
                      TextButton(
                        onPressed: controller.skip,
                        child: const Text('Skip'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: controller.next,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
