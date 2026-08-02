import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/profile_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_actions_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_security_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_connection_provider.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewStateProvider);
    final data = state.profile;
    final momentum = ref.watch(momentumEngineProvider);
    final identityStatus = ref.watch(identityAccountStatusProvider);
    final identityActionState = ref.watch(identityAccountActionsProvider);
    final accountSecurity = ref.watch(accountSecurityProvider);
    final accountConnections = ref.watch(accountConnectionProvider);

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
              const SizedBox(height: 12),
              _IdentityAccountCard(status: identityStatus),
              const SizedBox(height: 8),
              _AccountSecurityCard(security: accountSecurity),
              const SizedBox(height: 8),
              _ConnectedAccountsCard(connections: accountConnections),
              const SizedBox(height: 8),
              _IdentityAccountActionsCard(
                status: identityStatus,
                actionState: identityActionState,
                onInitialize: () => ref
                    .read(identityAccountActionsProvider.notifier)
                    .initializeLocalIdentity(
                      displayName: data.name.trim().isEmpty
                          ? 'Profile'
                          : data.name.trim(),
                    ),
                onRestore: () => ref
                    .read(identityAccountActionsProvider.notifier)
                    .restoreLocalIdentity(),
                onSignOut: () => ref
                    .read(identityAccountActionsProvider.notifier)
                    .signOutLocalIdentity(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xAA07111F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.neonViolet.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(
                        color: AppColors.neonViolet,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage subscription and billing options.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(RoutePaths.subscriptionManagement),
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: const Text('Billing center'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricCard(
                    label: 'Level',
                    value: '${data.level}',
                    color: AppColors.neonCyan,
                  ),
                  _MetricCard(
                    label: 'XP',
                    value: '${data.xp}',
                    color: AppColors.memoryAmber,
                  ),
                  _MetricCard(
                    label: 'Streak',
                    value: '${data.streak}d',
                    color: AppColors.neonViolet,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
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
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.20),
                  ),
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
                      'Momentum',
                      style: TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      momentum.trend,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      momentum.forecast,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Momentum ${momentum.score}%  ·  Energy ${momentum.energyPercent}%  ·  Pressure ${momentum.pressurePercent}%',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recovery: ${momentum.recovery}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA07111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _OperatorStatusCard extends StatelessWidget {
  const _OperatorStatusCard({
    required this.level,
    required this.xp,
    required this.streak,
  });

  final int level;
  final int xp;
  final int streak;

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityAccountCard extends StatelessWidget {
  const _IdentityAccountCard({required this.status});

  final IdentityAccountStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonViolet.withValues(alpha: 0.08),
            AppColors.neonCyan.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account identity',
            style: TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status.accountLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sync: ${status.syncLabel}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status.emailLabel,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSecurityCard extends StatelessWidget {
  const _AccountSecurityCard({required this.security});

  final AccountSecurityState security;

  Color get _accent {
    switch (security.level) {
      case AccountSecurityLevel.trusted:
        return AppColors.neonCyan;
      case AccountSecurityLevel.verified:
        return AppColors.neonViolet;
      case AccountSecurityLevel.basic:
        return AppColors.memoryAmber;
      case AccountSecurityLevel.signedOut:
        return AppColors.recallRed;
    }
  }

  String get _label {
    switch (security.level) {
      case AccountSecurityLevel.trusted:
        return 'TRUSTED';
      case AccountSecurityLevel.verified:
        return 'VERIFIED';
      case AccountSecurityLevel.basic:
        return 'BASIC';
      case AccountSecurityLevel.signedOut:
        return 'SIGNED OUT';
    }
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
            _accent.withValues(alpha: 0.08),
            AppColors.neonViolet.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECURITY STATUS  ·  $_label',
            style: TextStyle(
              color: _accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            security.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            security.recommendation,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SecurityChip(
                label: 'EMAIL',
                value: security.emailVerified ? 'VERIFIED' : 'PENDING',
                color: security.emailVerified
                    ? AppColors.neonCyan
                    : AppColors.memoryAmber,
              ),
              _SecurityChip(
                label: 'SESSION',
                value: security.sessionActive ? 'ACTIVE' : 'INACTIVE',
                color: security.sessionActive
                    ? AppColors.neonCyan
                    : AppColors.recallRed,
              ),
              _SecurityChip(
                label: 'DEVICE',
                value: security.deviceTrusted ? 'TRUSTED' : 'LOCAL',
                color: security.deviceTrusted
                    ? AppColors.neonViolet
                    : Colors.white38,
              ),
              _SecurityChip(
                label: 'RESET',
                value: security.passwordResetAvailable ? 'READY' : 'N/A',
                color: security.passwordResetAvailable
                    ? AppColors.memoryAmber
                    : Colors.white38,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityChip extends StatelessWidget {
  const _SecurityChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _IdentityAccountActionsCard extends StatelessWidget {
  const _IdentityAccountActionsCard({
    required this.status,
    required this.actionState,
    required this.onInitialize,
    required this.onRestore,
    required this.onSignOut,
  });

  final IdentityAccountStatus status;
  final AsyncValue<void> actionState;
  final VoidCallback onInitialize;
  final VoidCallback onRestore;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final bool isBusy = actionState.isLoading;
    final bool hasError = actionState.hasError;
    final String? errorLabel = hasError
        ? _safeErrorLabel(actionState.error)
        : null;
    final String primaryLabel = status.hasIdentity
        ? 'SIGN OUT LOCAL'
        : 'CREATE LOCAL IDENTITY';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.memoryAmber.withValues(alpha: 0.08),
            AppColors.neonCyan.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT ACTIONS',
            style: TextStyle(
              color: AppColors.memoryAmber,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isBusy
                ? 'Updating account...'
                : hasError
                ? 'Account action failed. Try again.'
                : 'Local identity ready.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          if (errorLabel != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              errorLabel,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _IdentityActionButton(
                label: primaryLabel,
                color: status.hasIdentity
                    ? AppColors.recallRed
                    : AppColors.neonCyan,
                onTap: isBusy
                    ? () {}
                    : (status.hasIdentity ? onSignOut : onInitialize),
              ),
              _IdentityActionButton(
                label: 'RESTORE LOCAL',
                color: AppColors.neonViolet,
                onTap: isBusy ? () {} : onRestore,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _safeErrorLabel(Object? error) {
    if (error == null) {
      return null;
    }

    final String typeName = error.runtimeType.toString();
    if (typeName.contains('TimeoutException')) {
      return 'Action timed out. Retry when ready.';
    }
    if (typeName.contains('FormatException')) {
      return 'Action response was invalid. Try again.';
    }
    return 'A temporary account action error occurred.';
  }
}

class _IdentityActionButton extends StatelessWidget {
  const _IdentityActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
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
          ...visibleConnections.map((AccountConnection connection) {
            final Color accent = _colorFor(connection.status);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
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
