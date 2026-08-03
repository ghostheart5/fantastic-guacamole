import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/profile_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_connection_provider.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/identity_session_bridge_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewStateProvider);
    final data = state.profile;
    final accountConnections = ref.watch(accountConnectionProvider);
    final identitySession = ref.watch(identitySessionBridgeProvider);
    final ChronoSparkIdentity? identity = ref.watch(identityAccountProvider);
    final bool hasMockSession = ref.watch(mockAuthSessionProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgProfile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ProfileHeader(
                name: data.name,
                level: data.level,
                onBack: () => ref.read(appFlowProvider.notifier).toNexus(),
                onOpenSettings: () =>
                    ref.read(appFlowProvider.notifier).toSettings(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Keep your identity, linked services, and billing in one place.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              _IdentityStatusCard(session: identitySession, identity: identity),
              const SizedBox(height: 8),
              _ProgressionStatusCard(
                level: data.level,
                xp: data.xp,
                streak: data.streak,
                longestStreak: data.longestStreak,
                onOpenProgression: () =>
                    ref.read(appFlowProvider.notifier).toProgression(),
              ),
              const SizedBox(height: 8),
              _DangerZoneCard(
                hasMockSession: hasMockSession,
                onSignOut: () =>
                    _signOut(context, ref, hasMockSession: hasMockSession),
                onDeleteAccount: hasMockSession
                    ? null
                    : () => context.push(
                        ref.read(routeSurfaceProvider).deleteAccount,
                      ),
              ),
              const SizedBox(height: 8),
              _ConnectedAccountsCard(connections: accountConnections),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0x9907111F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.neonViolet.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(
                        color: AppColors.neonViolet,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage subscription and billing options.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push(RoutePaths.subscriptionManagement),
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: const Text('Billing center'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.neonViolet,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref, {
    required bool hasMockSession,
  }) async {
    final routes = ref.read(routeSurfaceProvider);
    try {
      if (hasMockSession) {
        ref.read(mockAuthSessionProvider.notifier).set(false);
      } else {
        await ref.read(authControllerProvider.notifier).signOut();
      }
      if (!context.mounted) {
        return;
      }
      context.go(routes.login);
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }
}

class _ProgressionStatusCard extends StatelessWidget {
  const _ProgressionStatusCard({
    required this.level,
    required this.xp,
    required this.streak,
    required this.longestStreak,
    required this.onOpenProgression,
  });

  final int level;
  final int xp;
  final int streak;
  final int longestStreak;
  final VoidCallback onOpenProgression;

  String get _status {
    if (streak >= 21) {
      return 'Elite rhythm established';
    }
    if (streak >= 7) {
      return 'Strong rhythm established';
    }
    if (xp > 0) {
      return 'Progress active';
    }
    return 'Profile ready';
  }

  String get _signal {
    if (level >= 10) {
      return 'Advanced progress level reached.';
    }
    if (streak >= 7) {
      return 'Consistency is building stronger momentum.';
    }
    return 'Complete actions to strengthen your progress.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonCyan.withValues(alpha: 0.08),
            AppColors.neonViolet.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonCyan.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.38),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonCyan.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin_circle_rounded,
              color: AppColors.neonCyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress status',
                  style: TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _signal,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'XP $xp • Next ${50 - (xp % 50)} • Best streak $longestStreak',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onOpenProgression,
            style: TextButton.styleFrom(foregroundColor: AppColors.neonCyan),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _IdentityStatusCard extends StatelessWidget {
  const _IdentityStatusCard({required this.session, required this.identity});

  final IdentitySessionBridgeState session;
  final ChronoSparkIdentity? identity;

  String get _syncLabel {
    final ChronoSparkIdentitySyncStatus? syncStatus = identity?.syncStatus;
    if (syncStatus == null) {
      return 'NOT LINKED';
    }
    return syncStatus.name.toUpperCase();
  }

  String get _providerLabel {
    return session.authProvider.isEmpty ? 'NONE' : session.authProvider;
  }

  String get _missionLabel {
    final String mission = identity?.lifeOsMission?.trim() ?? '';
    if (mission.isNotEmpty) {
      return mission;
    }
    final String stage = identity?.identityStage?.trim() ?? '';
    if (stage.isNotEmpty) {
      return 'Identity stage: $stage';
    }
    return 'Identity profile is active and ready for connected progression.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x9907111F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Identity',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _missionLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ProfileSignalPill(label: 'Tier', value: session.accountTier),
              _ProfileSignalPill(label: 'Provider', value: _providerLabel),
              _ProfileSignalPill(label: 'Sync', value: _syncLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.hasMockSession,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final bool hasMockSession;
  final VoidCallback onSignOut;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x99FF1325),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danger zone',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasMockSession
                ? 'Mock session controls are active. You can safely log out of the current local session.'
                : 'Manage high-impact account actions here. Logging out ends the session. Delete Account opens the hosted deletion flow.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
              ),
              if (!hasMockSession)
                OutlinedButton.icon(
                  onPressed: onDeleteAccount,
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSignalPill extends StatelessWidget {
  const _ProfileSignalPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConnectedAccountsCard extends StatelessWidget {
  const _ConnectedAccountsCard({required this.connections});

  final AccountConnectionState connections;

  Color _colorFor(AccountConnectionStatus status) {
    switch (status) {
      case AccountConnectionStatus.connected:
        return AppColors.neonCyan;
      case AccountConnectionStatus.pending:
        return AppColors.memoryAmber;
      case AccountConnectionStatus.disconnected:
        return Colors.white38;
    }
  }

  String _statusLabel(AccountConnectionStatus status) {
    switch (status) {
      case AccountConnectionStatus.connected:
        return 'CONNECTED';
      case AccountConnectionStatus.pending:
        return 'PENDING';
      case AccountConnectionStatus.disconnected:
        return 'NOT LINKED';
    }
  }

  String _providerLabel(ChronoSparkAuthProvider provider) {
    switch (provider) {
      case ChronoSparkAuthProvider.email:
        return 'EMAIL';
      case ChronoSparkAuthProvider.google:
        return 'GOOGLE';
      default:
        return 'UNAVAILABLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AccountConnection> visibleConnections = connections.connections
        .where(
          (AccountConnection connection) =>
              connection.provider == ChronoSparkAuthProvider.email ||
              connection.provider == ChronoSparkAuthProvider.google,
        )
        .toList(growable: false);

    final int connectedCount = visibleConnections
        .where(
          (AccountConnection connection) =>
              connection.status == AccountConnectionStatus.connected,
        )
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonCyan.withValues(alpha: 0.06),
            AppColors.neonViolet.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connected accounts',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$connectedCount connected identity ${connectedCount == 1 ? 'source' : 'sources'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleConnections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'No linked services yet.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            )
          else
            ...visibleConnections.map((AccountConnection connection) {
              final Color accent = _colorFor(connection.status);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _providerLabel(connection.provider),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        _statusLabel(connection.status),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
