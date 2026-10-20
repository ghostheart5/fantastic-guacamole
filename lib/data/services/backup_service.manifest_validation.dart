part of 'backup_service.dart';

extension _BackupManifestValidation on BackupService {
  void _validateManifest(Object? rawManifest, {required String version}) {
    final Map<String, dynamic> manifest = _strictStringKeyMap(
      rawManifest,
      field: 'manifest',
    );
    final bool isCurrent =
        version == BackupService._backupVersion ||
        version == BackupService._planningCloudVersion;
    final bool isPlanningCloud = version == BackupService._planningCloudVersion;
    if ((!isCurrent &&
            manifest['manifestVersion'] != 1 &&
            manifest['manifestVersion'] != 2) ||
        (isCurrent && manifest['manifestVersion'] != 2)) {
      throw const FormatException('Unsupported backup manifest version.');
    }
    if (isCurrent &&
        (manifest['backupKind'] !=
                (isPlanningCloud
                    ? 'encryptedPlanningSnapshot'
                    : 'portableLocal') ||
            manifest['cloudRestoreIncluded'] != isPlanningCloud)) {
      throw const FormatException(
        'Backup manifest does not describe a contained portable local backup.',
      );
    }
    if (!isCurrent) {
      for (final String key in <String>[
        'includedDomains',
        'cloudReplicatedDomains',
        'excludedDomains',
      ]) {
        _strictUniqueStringSet(manifest[key], field: 'manifest.$key');
      }
      if (manifest['domains'] is! List) {
        throw const FormatException('Backup manifest domains are invalid.');
      }
      return;
    }
    final Map<String, dynamic> expected = isPlanningCloud
        ? planningCloudBackupManifest()
        : accountDataBackupManifest();
    for (final String key in <String>[
      'includedDomains',
      'cloudReplicatedDomains',
      'excludedDomains',
    ]) {
      final Set<String> actualValues = _strictUniqueStringSet(
        manifest[key],
        field: 'manifest.$key',
      );
      final Set<String> expectedValues = (expected[key] as List<dynamic>)
          .cast<String>()
          .toSet();
      if (!_sameSet(actualValues, expectedValues)) {
        throw FormatException('Backup manifest $key does not match this app.');
      }
    }

    final Object? rawDomains = manifest['domains'];
    if (rawDomains is! List) {
      throw const FormatException('Backup manifest domains are invalid.');
    }
    final Map<String, String> actualStatuses = <String, String>{};
    for (final Object? rawDomain in rawDomains) {
      final Map<String, dynamic> domain = _strictStringKeyMap(
        rawDomain,
        field: 'manifest.domains',
      );
      final String id = domain['id'] is String
          ? (domain['id'] as String).trim()
          : '';
      final String status = domain['backupStatus'] is String
          ? (domain['backupStatus'] as String).trim()
          : '';
      if (id.isEmpty || status.isEmpty || actualStatuses.containsKey(id)) {
        throw const FormatException('Backup manifest domain is invalid.');
      }
      actualStatuses[id] = status;
    }
    final Map<String, String> expectedStatuses = <String, String>{
      for (final domain
          in (expected['domains'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
        domain['id'] as String: domain['backupStatus'] as String,
    };
    if (!_sameSet(actualStatuses.keys.toSet(), expectedStatuses.keys.toSet())) {
      throw const FormatException(
        'Backup manifest domain inventory does not match this app.',
      );
    }
    for (final MapEntry<String, String> entry in expectedStatuses.entries) {
      if (actualStatuses[entry.key] != entry.value) {
        throw const FormatException(
          'Backup manifest domain status does not match this app.',
        );
      }
    }
  }
}
