import 'package:flutter/material.dart';

class SystemNavItem {
  const SystemNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0x1C000000),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(items.length, (int index) {
          final bool selected = currentIndex == index;
          final Color color = selected ? const Color(0xFFC2A7FF) : const Color(0xFF8E849E);
          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(10),
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
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
