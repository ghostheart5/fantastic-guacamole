import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SoulMapScreen extends ConsumerWidget {
  const SoulMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SoulMapAlignment alignment = ref.watch(soulMapAlignmentProvider);
    final SoulMapSummary summary = ref.watch(soulMapSummaryProvider);
    final SoulMapProfile profile = ref.watch(soulMapProfileProvider);
    final SoulMapFutureSelfComparison comparison = ref.watch(
      soulMapFutureSelfComparisonProvider,
    );

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () =>
                          ref.read(appFlowProvider.notifier).toSmartCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: _HeaderTitle()),
                  ],
                ),
                const SizedBox(height: 24),
                _Panel(
                  borderColor: AppColors.neonViolet.withValues(alpha: 0.25),
                  title: 'ONE-SENTENCE DEFINITION',
                  titleColor: AppColors.neonViolet,
                  child: Text(
                    summary.definition,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  borderColor: AppColors.neonCyan.withValues(alpha: 0.25),
                  title: 'AUTHORED SOULMAP',
                  titleColor: AppColors.neonCyan,
                  trailing: TextButton(
                    onPressed: () => _openSoulMapEditor(context, ref, profile),
                    child: const Text('EDIT'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KeyValueLine(
                        'Purpose',
                        _valueOrPlaceholder(profile.purposeStatement),
                      ),
                      _KeyValueLine(
                        'Identity',
                        _valueOrPlaceholder(profile.identityStatement),
                      ),
                      _KeyValueLine(
                        'Future Self 1Y/5Y/10Y',
                        '${_valueOrPlaceholder(profile.futureSelfOneYear)} | ${_valueOrPlaceholder(profile.futureSelfFiveYears)} | ${_valueOrPlaceholder(profile.futureSelfTenYears)}',
                      ),
                      _KeyValueLine(
                        'Vision',
                        _valueOrPlaceholder(profile.visionStatement),
                      ),
                      _KeyValueLine(
                        'Legacy',
                        _valueOrPlaceholder(profile.legacyGoal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  borderColor: AppColors.neonViolet.withValues(alpha: 0.25),
                  title: 'SOULMAP ANALYSIS',
                  titleColor: AppColors.neonViolet,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScoreRow(
                        label: 'Purpose Alignment',
                        score:
                            alignment.scores[SoulMapDimension.purpose]?.score ??
                            0,
                      ),
                      _ScoreRow(
                        label: 'Identity Alignment',
                        score:
                            alignment
                                .scores[SoulMapDimension.identity]
                                ?.score ??
                            0,
                      ),
                      _ScoreRow(
                        label: 'Values Alignment',
                        score:
                            alignment
                                .scores[SoulMapDimension.coreValues]
                                ?.score ??
                            0,
                      ),
                      _ScoreRow(
                        label: 'Future Self Progress',
                        score:
                            alignment
                                .scores[SoulMapDimension.futureSelf]
                                ?.score ??
                            0,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Strongest Area: ${soulMapDimensionTitle(alignment.strongest)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Weakest Area: ${soulMapDimensionTitle(alignment.weakest)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alignment.recommendations.last,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Current vs Future: ${comparison.currentSelfAlignment}% vs ${comparison.futureSelfReadiness}% | Gap ${comparison.gap}% (${comparison.stance})',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  borderColor: AppColors.neonCyan.withValues(alpha: 0.25),
                  title: 'SOULMAP SECTIONS',
                  titleColor: AppColors.neonCyan,
                  child: Column(
                    children: SoulMapDimension.values
                        .map(
                          (SoulMapDimension dimension) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DimensionCard(
                              score: alignment.scores[dimension]!,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) => const LinearGradient(
            colors: <Color>[AppColors.neonViolet, AppColors.neonCyan],
          ).createShader(bounds),
          child: const Text(
            'SOUL MAP',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ),
        const Text(
          'IDENTITY + PURPOSE NAVIGATION SYSTEM',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.borderColor,
    required this.title,
    required this.titleColor,
    required this.child,
    this.trailing,
  });

  final Color borderColor;
  final String title;
  final Color titleColor;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2.3,
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine(this.keyText, this.valueText);

  final String keyText;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$keyText: $valueText',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        '$label: $score%',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({required this.score});

  final SoulMapDimensionScore score;

  @override
  Widget build(BuildContext context) {
    final SoulMapDimensionDefinition definition = score.definition;
    final double widthFactor = (score.score / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${definition.title} ${score.score}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            definition.prompt,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.12)),
                  FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.neonViolet,
                            AppColors.neonCyan,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _valueOrPlaceholder(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? 'not set' : trimmed;
}

Future<void> _openSoulMapEditor(
  BuildContext context,
  WidgetRef ref,
  SoulMapProfile current,
) async {
  final TextEditingController purposeCtrl = TextEditingController(
    text: current.purposeStatement,
  );
  final TextEditingController identityCtrl = TextEditingController(
    text: current.identityStatement,
  );
  final TextEditingController future1Ctrl = TextEditingController(
    text: current.futureSelfOneYear,
  );
  final TextEditingController future5Ctrl = TextEditingController(
    text: current.futureSelfFiveYears,
  );
  final TextEditingController future10Ctrl = TextEditingController(
    text: current.futureSelfTenYears,
  );
  final TextEditingController visionCtrl = TextEditingController(
    text: current.visionStatement,
  );
  final TextEditingController passionsCtrl = TextEditingController(
    text: current.passionsStatement,
  );
  final TextEditingController legacyCtrl = TextEditingController(
    text: current.legacyGoal,
  );
  final TextEditingController directionCtrl = TextEditingController(
    text: current.lifeDirectionStatement,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF050D1A),
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit SoulMap Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _editorField(purposeCtrl, 'Purpose'),
              _editorField(identityCtrl, 'Identity Statement'),
              _editorField(future1Ctrl, 'Future Self 1 Year'),
              _editorField(future5Ctrl, 'Future Self 5 Years'),
              _editorField(future10Ctrl, 'Future Self 10 Years'),
              _editorField(visionCtrl, 'Vision'),
              _editorField(passionsCtrl, 'Passions'),
              _editorField(legacyCtrl, 'Legacy Goal'),
              _editorField(directionCtrl, 'Life Direction Statement'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final SoulMapProfile next = current.copyWith(
                      purposeStatement: purposeCtrl.text.trim(),
                      identityStatement: identityCtrl.text.trim(),
                      futureSelfOneYear: future1Ctrl.text.trim(),
                      futureSelfFiveYears: future5Ctrl.text.trim(),
                      futureSelfTenYears: future10Ctrl.text.trim(),
                      visionStatement: visionCtrl.text.trim(),
                      passionsStatement: passionsCtrl.text.trim(),
                      legacyGoal: legacyCtrl.text.trim(),
                      lifeDirectionStatement: directionCtrl.text.trim(),
                    );
                    await ref
                        .read(soulMapProfileProvider.notifier)
                        .setProfile(next);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save SoulMap Profile'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  purposeCtrl.dispose();
  identityCtrl.dispose();
  future1Ctrl.dispose();
  future5Ctrl.dispose();
  future10Ctrl.dispose();
  visionCtrl.dispose();
  passionsCtrl.dispose();
  legacyCtrl.dispose();
  directionCtrl.dispose();
}

Widget _editorField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.neonCyan),
        ),
      ),
      minLines: 1,
      maxLines: 3,
    ),
  );
}
