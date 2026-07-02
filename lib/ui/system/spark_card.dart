import 'package:flutter/material.dart';

class SparkCard extends StatelessWidget {
  const SparkCard({
    super.key,
    this.primary = false,
    this.title = 'Execute Task',
    this.subtitle = 'Priority action',
  });

  final bool primary;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = primary
        ? const <Color>[Color(0xFFC2A7FF), Color(0xFFFF8FB6)]
        : const <Color>[Color(0x14FFFFFF), Color(0x26FFFFFF)];

    return Semantics(
      label: '$subtitle. $title',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: colors),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: primary
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55C2A7FF),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFE9E1F5)),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
