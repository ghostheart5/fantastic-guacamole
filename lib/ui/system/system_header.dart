import 'package:flutter/material.dart';

class SystemHeader extends StatelessWidget {
  const SystemHeader({
    required this.sectionTitle,
    super.key,
    this.alertCount = 0,
    this.onNotificationTap,
  });

  final String sectionTitle;
  final int alertCount;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0x05000000),
        border: Border(bottom: BorderSide(color: Color(0x18FFFFFF))),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'ChronoSpark',
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFFECE8F9),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            sectionTitle,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFA99DBE),
            ),
          ),
          const SizedBox(width: 12),
          const ExcludeSemantics(
            child: Icon(Icons.bolt_rounded, color: Color(0xFFC2A7FF), size: 18),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: alertCount > 0
                ? '$alertCount alert${alertCount == 1 ? '' : 's'}'
                : 'No alerts',
            child: InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: <Widget>[
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFFFF8FB6),
                        size: 18,
                      ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
