// lib/tutorial/tutorial_target_registry.dart

import 'package:flutter/widgets.dart';

class TutorialTargetRegistry {
  TutorialTargetRegistry._();
  static final TutorialTargetRegistry instance = TutorialTargetRegistry._();

  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey keyFor(String id) {
    return _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tutorial:$id'));
  }

  Rect? rectFor(String id) {
    final GlobalKey? key = _keys[id];
    final BuildContext? context = key?.currentContext;
    if (context == null) return null;

    final RenderObject? render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;

    final Offset offset = render.localToGlobal(Offset.zero);
    return offset & render.size;
  }

  void unregister(String id) {
    _keys.remove(id);
  }
}

class TutorialTarget extends StatefulWidget {
  const TutorialTarget({
    super.key,
    required this.id,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final String id;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  late final GlobalKey _key;

  @override
  void initState() {
    super.initState();
    _key = TutorialTargetRegistry.instance.keyFor(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );
  }
}
