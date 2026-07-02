import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/paywall_config.dart';
import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/features/paywall/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    AppAnalytics.track(
      'paywall_viewed',
      params: <String, Object?>{'testing_mode': paywallTestingMode},
    );
  }

  Future<void> _unlock(String planId) async {
    try {
      final SubscriptionState subscription = await ref
          .read(paywallServiceProvider)
          .startSubscription(planId);
      ref.read(runtimePremiumAccessProvider.notifier).set(subscription.isActive);
      ref.invalidate(paywallSubscriptionProvider);
      ref.invalidate(aiCreditWalletProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = paywallTestingMode ? 'Unlocked for testing.' : 'Subscription activated.';
      });
      if (paywallTestingMode) {
        Logger.log('Paywall', 'Unlocked for testing.');
      }
      AppAnalytics.track(
        'paywall_unlock',
        params: <String, Object?>{'plan_id': planId, 'testing_mode': paywallTestingMode},
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to activate subscription right now. Please try again.';
      });
    }
  }

  Future<void> _restore() async {
    try {
      final SubscriptionState subscription = await ref
          .read(paywallServiceProvider)
          .restorePurchases();
      ref.read(runtimePremiumAccessProvider.notifier).set(subscription.isActive);
      ref.invalidate(paywallSubscriptionProvider);
      ref.invalidate(aiCreditWalletProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = paywallTestingMode ? 'Unlocked for testing.' : 'Purchases restored.';
      });
      AppAnalytics.track(
        'paywall_restore',
        params: <String, Object?>{'testing_mode': paywallTestingMode},
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to restore purchases right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PaywallEntity> configAsync = ref.watch(paywallConfigProvider);
    final AsyncValue<SubscriptionState> subscriptionAsync = ref.watch(paywallSubscriptionProvider);
    final AsyncValue<AiCreditWallet> walletAsync = ref.watch(aiCreditWalletProvider);
    final PaywallPrompt? prompt = ref.watch(paywallPromptProvider);
    final bool isPremium = ref.watch(appAccessProvider).hasPremiumAccess;

    if (configAsync.isLoading || subscriptionAsync.isLoading || walletAsync.isLoading) {
      return const AnimatedSystemBackground(
        backgroundAssetPath: AppAssets.bgSettings,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.neonCyan, strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final PaywallEntity config =
        configAsync.asData?.value ??
        const PaywallEntity(
          featureId: 'premium',
          title: 'AI Credits + Premium',
          body: 'Unlock AI credits, premium coaching, deeper memory, and advanced tools.',
          plans: <PaywallPlan>[],
          isUnlocked: false,
        );
    final SubscriptionState? subscription = subscriptionAsync.asData?.value;
    final AiCreditWallet? wallet = walletAsync.asData?.value;

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                        return;
                      }
                      context.go(RoutePaths.settings);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.neonCyan,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonCyan, AppColors.neonViolet],
                          ).createShader(bounds),
                          child: Text(
                            (config.title).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          paywallTestingMode ? 'UNLOCKED FOR TESTING' : 'SUBSCRIPTION ACCESS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _HeroCard(
                title: config.title,
                body: config.body,
                isPremium: isPremium || paywallTestingMode || subscription?.isActive == true,
                wallet: wallet,
              ),
              if (prompt != null) ...[const SizedBox(height: 14), _PromptBanner(prompt: prompt)],
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _statusMessage ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              _ComparisonGrid(wallet: wallet),
              const SizedBox(height: 18),
              if (paywallTestingMode || subscription?.isActive == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Unlocked for testing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ...config.plans.map(
                (PaywallPlan plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050D1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: plan.isFeatured
                            ? AppColors.neonViolet.withValues(alpha: 0.35)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (plan.isFeatured)
                              const Flexible(
                                child: Text(
                                  'BEST VALUE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.neonViolet,
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plan.priceLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (plan.aiCreditsIncluded > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${plan.aiCreditsIncluded} AI credits included',
                            style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          plan.description,
                          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                        ),
                        if (plan.benefits.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...plan.benefits.map(
                            (String benefit) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: AppColors.neonCyan,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      benefit,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: plan.isAvailable ? () => _unlock(plan.id) : null,
                                child: Text(paywallTestingMode ? 'Simulate unlock' : 'Choose plan'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _restore, child: const Text('Restore Purchases')),
              const SizedBox(height: 10),
              Text(
                paywallTestingMode
                    ? 'Testing mode is active; purchases are simulated.'
                    : 'Cancel anytime. Credits renew automatically. No hidden fees.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    required this.isPremium,
    required this.wallet,
  });

  final String title;
  final String body;
  final bool isPremium;
  final AiCreditWallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? AppColors.neonCyan.withValues(alpha: 0.3)
              : AppColors.neonViolet.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isPremium ? AppColors.neonCyan : AppColors.neonViolet,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPremium ? 'PREMIUM ACTIVE' : 'AI CREDIT GATE',
                style: TextStyle(
                  color: isPremium ? AppColors.neonCyan : AppColors.neonViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          if (wallet case final AiCreditWallet safeWallet) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CreditStat(label: 'Credits left', value: '${safeWallet.balance}'),
                  ),
                  Expanded(
                    child: _CreditStat(label: 'Tier', value: safeWallet.tier.toUpperCase()),
                  ),
                  Expanded(
                    child: _CreditStat(label: 'Resets', value: _formatReset(safeWallet.resetAt)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReset(DateTime resetAt) {
    final Duration remaining = resetAt.difference(DateTime.now());
    if (remaining.inHours <= 0) {
      return 'Soon';
    }
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d';
    }
    return '${remaining.inHours}h';
  }
}

class _CreditStat extends StatelessWidget {
  const _CreditStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ComparisonGrid extends StatelessWidget {
  const _ComparisonGrid({required this.wallet});

  final AiCreditWallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ComparisonCard(
          title: 'Free',
          subtitle: 'Keep the habit alive',
          color: Colors.white54,
          bullets: const <String>[
            'Basic focus and planning',
            'Starter AI credits',
            'Limited voice and memory',
          ],
          badge: wallet?.tier == 'free' ? 'Current' : null,
        ),
        _ComparisonCard(
          title: 'Premium',
          subtitle: 'Scale the AI workflow',
          color: AppColors.neonCyan,
          bullets: const <String>[
            'Monthly AI credit bundle',
            'Deeper memory and insights',
            'Voice and advanced agents',
          ],
          badge: wallet?.tier == 'premium' ? 'Active' : 'Upgrade',
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bullets,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<String> bullets;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width < 420
        ? double.infinity
        : (MediaQuery.of(context).size.width - 52) / 2;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge ?? '',
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          ...bullets.map(
            (String bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
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

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.prompt});

  final PaywallPrompt prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonViolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            prompt.message,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          if (prompt.remainingCredits != null) ...[
            const SizedBox(height: 6),
            Text(
              'Remaining credits: ${prompt.remainingCredits}',
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
