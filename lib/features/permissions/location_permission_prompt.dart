import 'package:fantastic_guacamole/system/location/location_service.dart';
import 'package:flutter/material.dart';

class LocationPermissionPrompt extends StatefulWidget {
  const LocationPermissionPrompt({
    required this.result,
    required this.onRequestLocation,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    super.key,
  });

  final AppLocationResult? result;
  final Future<AppLocationResult> Function() onRequestLocation;
  final Future<bool> Function() onOpenAppSettings;
  final Future<bool> Function() onOpenLocationSettings;

  @override
  State<LocationPermissionPrompt> createState() =>
      _LocationPermissionPromptState();
}

class _LocationPermissionPromptState extends State<LocationPermissionPrompt> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppLocationResult? result = widget.result;
    final AppLocationStatus? status = result?.status;
    final bool ready = status == AppLocationStatus.ready;
    final String subtitle = _subtitle(result);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.location_on : Icons.location_searching,
                color: ready ? Colors.greenAccent : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Location Permission',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _requestLocation,
                child: Text(_busy ? 'Checking...' : 'Enable Location'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => widget.onOpenAppSettings(),
                child: const Text('App Settings'),
              ),
              if (status == AppLocationStatus.serviceDisabled)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => widget.onOpenLocationSettings(),
                  child: const Text('Location Settings'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocation() async {
    setState(() => _busy = true);
    try {
      await widget.onRequestLocation();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

String _subtitle(AppLocationResult? result) {
  if (result == null) {
    return 'Optional. ChronoSpark only checks location after you tap enable.';
  }
  final AppLocationSnapshot? snapshot = result.snapshot;
  if (snapshot == null) {
    return result.message;
  }
  return 'Ready · approx. ${snapshot.accuracyMeters.toStringAsFixed(0)}m accuracy.';
}
