import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductAdvisorScreen extends ConsumerWidget {
  const ProductAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(productInsightsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060D1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.neonCyan,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.neonCyan, AppColors.neonViolet],
          ).createShader(bounds),
          child: const Text(
            'STRATEGIC ADVISOR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            insightsAsync.when(
              data: (insights) => _InsightsList(
                insights: insights
                    .map(
                      (insight) => _InsightView(
                        issue: insight.issue,
                        cause: insight.cause,
                        recommendation: insight.recommendation,
                      ),
                    )
                    .toList(growable: false),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AppColors.neonCyan),
                ),
              ),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const SizedBox(height: 16),
            _RefreshButton(
              onRefresh: () {
                ref.invalidate(productInsightsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsList extends StatelessWidget {
  const _InsightsList({required this.insights});
  final List<_InsightView> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _EmptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'PRIMARY SIGNAL'),
        const SizedBox(height: 8),
        _InsightCard(insight: insights.first, isTop: true),
        if (insights.length > 1) ...[
          const SizedBox(height: 20),
          const _SectionHeader(label: 'SUPPORTING SIGNALS'),
          const SizedBox(height: 8),
          ...insights
              .skip(1)
              .map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InsightCard(insight: i, isTop: false),
                ),
              ),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.isTop});
  final _InsightView insight;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final accent = isTop ? AppColors.neonCyan : AppColors.neonViolet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isTop ? 0.1 : 0.05),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.issue,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Label(label: 'Detected Cause', value: insight.cause),
          const SizedBox(height: 6),
          _Label(label: 'Recommended Move', value: insight.recommendation),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 2.5,
        color: AppColors.neonCyan,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'Signal matrix warming up.\nUse ChronoSpark to generate stronger strategic guidance.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Error: $message',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}

class _InsightView {
  const _InsightView({
    required this.issue,
    required this.cause,
    required this.recommendation,
  });

  final String issue;
  final String cause;
  final String recommendation;
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRefresh,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.neonViolet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, color: AppColors.neonViolet, size: 16),
            SizedBox(width: 8),
            Text(
              'Rescan Signals',
              style: TextStyle(
                color: AppColors.neonViolet,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
