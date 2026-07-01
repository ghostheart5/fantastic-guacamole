import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';

/// Account deletion dialog and management widget
class AccountDeletionDialog extends StatelessWidget {
  const AccountDeletionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Account'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Deleting your account will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Remove all your data from our servers'),
            Text('• Cancel any active subscriptions'),
            Text('• Delete all saved tasks, missions, and logs'),
            SizedBox(height: 16),
            Text(
              'You can create a new account at any time with a different email address.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _handleAccountDeletion(context),
          child: const Text(
            'Delete Permanently',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAccountDeletion(BuildContext context) async {
    final appState = context.read<AppState>();

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Deleting Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we delete your account...'),
          ],
        ),
      ),
    );

    try {
      final success = await appState.deleteAccount();

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        // Close the original deletion dialog
        if (context.mounted) Navigator.of(context).pop();

        // Show success message and redirect to auth
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully.'),
            duration: Duration(seconds: 2),
          ),
        );

        // Redirect to login - the auth state listener will handle this
        // Wait a moment for FirebaseAuth to update
        await Future.delayed(const Duration(seconds: 1));
      } else {
        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();

        // Show error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appState.runtimeError ?? 'Failed to delete account'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Settings tile for account deletion
class AccountDeletionTile extends StatelessWidget {
  const AccountDeletionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Delete Account'),
      subtitle: const Text('Permanently delete all data and account'),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => const AccountDeletionDialog(),
        );
      },
      tileColor: Colors.red.withValues(alpha: 0.1),
    );
  }
}
