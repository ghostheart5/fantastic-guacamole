import 'package:flutter/material.dart';

class SystemHeader extends StatelessWidget {
  const SystemHeader({
    required this.sectionTitle,
    required this.icon,
    this.iconAsset,
    super.key,
    this.alertCount = 0,
  });

  final String sectionTitle;
  final IconData icon;
  final String? iconAsset;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.66),
        border: Border(bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.42))),
      ),
      child: Row(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surface.withValues(alpha: 0.45),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
                ),
                alignment: Alignment.center,
                child: iconAsset != null
                    ? Image.asset(
                        iconAsset!,
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                          return Icon(icon, color: scheme.primary, size: 18);
                        },
                      )
                    : Icon(icon, color: scheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'ChronoSpark',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            sectionTitle,
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.82)),
          ),
          const SizedBox(width: 12),
<<<<<<< HEAD
          Icon(Icons.bolt_rounded, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Stack(
            alignment: Alignment.topRight,
            children: <Widget>[
              Icon(Icons.notifications_none_rounded, color: scheme.secondary, size: 18),
              if (alertCount > 0)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                ),
            ],
=======
          ExcludeSemantics(
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFC2A7FF), size: 18),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: alertCount > 0 ? '$alertCount alert${alertCount == 1 ? '' : 's'}' : 'No alerts',
            child: ExcludeSemantics(
              child: Stack(
                alignment: Alignment.topRight,
                children: <Widget>[
                  const Icon(Icons.notifications_none_rounded, color: Color(0xFFFF8FB6), size: 18),
                  if (alertCount > 0)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5D93),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
>>>>>>> 979f416d61500b1beabf212d483428b7431dab3e
          ),
        ],
      ),
    );
  }
}
