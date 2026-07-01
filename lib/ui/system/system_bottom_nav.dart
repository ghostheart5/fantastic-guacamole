import 'package:flutter/material.dart';

class SystemNavItem {
  const SystemNavItem({required this.label, required this.icon, this.iconAsset});

  final String label;
  final IconData icon;
  final String? iconAsset;
}

class SystemBottomNav extends StatelessWidget {
  const SystemBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<SystemNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.2),
        border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.32))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(items.length, (int index) {
          final bool selected = currentIndex == index;
          final Color color = selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7);
          return Expanded(
<<<<<<< HEAD
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.22)
                            : scheme.surface.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.52)
                              : scheme.outline.withValues(alpha: 0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: items[index].iconAsset != null
                          ? Image.asset(
                              items[index].iconAsset!,
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return Icon(items[index].icon, size: 18, color: color);
                              },
                            )
                          : Icon(items[index].icon, size: 18, color: color),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Text(
                        items[index].label,
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          height: 1.05,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
=======
            child: Semantics(
              label: items[index].label,
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(10),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(items[index].icon, size: 20, color: color),
                        const SizedBox(height: 4),
                        Text(
                          items[index].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ],
>>>>>>> 979f416d61500b1beabf212d483428b7431dab3e
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
