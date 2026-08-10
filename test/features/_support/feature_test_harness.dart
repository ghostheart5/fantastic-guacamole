import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class FeatureTestSpec {
  const FeatureTestSpec({
    required this.unitFiles,
    required this.integrationFiles,
  });

  final List<String> unitFiles;
  final List<String> integrationFiles;
}

const Map<String, FeatureTestSpec> _featureSpecs = <String, FeatureTestSpec>{
  'action_hub': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/nexus/ui/nexus_screen.dart',
      'lib/features/nexus/ui/nexus_screen.widgets.dart',
    ],
    integrationFiles: <String>[
      'lib/app/navigation_shell.dart',
      'lib/features/nexus/ui/nexus_screen.widgets.dart',
    ],
  ),
  'auth': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/auth/application/auth_controller.dart',
      'lib/features/auth/data/repositories/auth_repository_impl.dart',
    ],
    integrationFiles: <String>[
      'lib/features/auth/screens/auth_gate.dart',
      'lib/features/auth/ui/login_screen.dart',
    ],
  ),
  'creator': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/creator/widgets/dynamic_form.dart',
      'lib/features/creator/models/creator_workspace_mode.dart',
    ],
    integrationFiles: <String>[
      'lib/features/creator/ui/creator_screen.dart',
      'lib/features/creator/ui/widgets/creator_unified_workbench.dart',
    ],
  ),
  'daily_plan': FeatureTestSpec(
    unitFiles: <String>[
      'lib/state/providers/autonomous_daily_planner_provider.dart',
      'lib/features/auth/domain/usecases/plans/create_daily_plan_usecase.dart',
    ],
    integrationFiles: <String>[
      'lib/features/nexus/ui/nexus_screen.dart',
      'lib/features/si_console/ui/si_console_screen.dart',
    ],
  ),
  'navigation': FeatureTestSpec(
    unitFiles: <String>[
      'lib/app/navigation_shell.dart',
      'lib/state/providers/route_paths_provider.dart',
    ],
    integrationFiles: <String>[
      'lib/app/navigation_shell.dart',
      'lib/app/router/route_paths.dart',
    ],
  ),
  'nexus': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/nexus/ui/nexus_screen.dart',
      'lib/features/nexus/ui/nexus_screen.widgets.dart',
    ],
    integrationFiles: <String>[
      'lib/features/nexus/ui/nexus_screen.dart',
      'lib/app/navigation_shell.dart',
    ],
  ),
  'profile': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/profile/ui/profile_screen.dart',
      'lib/features/profile/ui/widgets/profile_header.dart',
    ],
    integrationFiles: <String>[
      'lib/features/profile/ui/profile_screen.dart',
      'lib/app/navigation_shell.dart',
    ],
  ),
  'progression': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/progression/ui/progression_screen.dart',
      'lib/features/progression/widgets/level_card.dart',
    ],
    integrationFiles: <String>[
      'lib/features/progression/ui/progression_screen.dart',
      'lib/features/nexus/ui/nexus_screen.widgets.dart',
    ],
  ),
  'scheduler': FeatureTestSpec(
    unitFiles: <String>[
      'lib/system/system_scheduler.dart',
      'lib/state/services/data_hygiene_scheduler.dart',
    ],
    integrationFiles: <String>[
      'lib/app/navigation_shell.dart',
      'lib/system/notifications/notification_scheduler.dart',
    ],
  ),
  'settings': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/settings/ui/settings_screen.sections.dart',
      'lib/features/settings/ui/settings_screen.dart',
    ],
    integrationFiles: <String>[
      'lib/features/settings/ui/settings_screen.dart',
      'lib/state/providers/route_paths_provider.dart',
    ],
  ),
  'si_console': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/si_console/ui/models/si_console_commands.dart',
      'lib/features/si_console/ui/models/si_console_response_validator.dart',
    ],
    integrationFiles: <String>[
      'lib/features/si_console/ui/si_console_screen.dart',
      'lib/features/nexus/ui/nexus_screen.dart',
    ],
  ),
  'storage': FeatureTestSpec(
    unitFiles: <String>[
      'lib/data/storage/storage_migration.dart',
      'lib/data/local/hive_storage.dart',
    ],
    integrationFiles: <String>[
      'lib/data/di/storage_providers.dart',
      'lib/features/auth/domain/usecases/settings/storage/storage_usecases.dart',
    ],
  ),
  'sync': FeatureTestSpec(
    unitFiles: <String>[
      'lib/data/services/sync_service.dart',
      'lib/state/services/offline_sync_queue_service.dart',
    ],
    integrationFiles: <String>[
      'lib/state/providers/sync_provider.dart',
      'lib/ui/widgets/offline_banner.dart',
    ],
  ),
  'tasks': FeatureTestSpec(
    unitFiles: <String>[
      'lib/engine/tasks/task_filter.dart',
      'lib/state/providers/task_provider.dart',
    ],
    integrationFiles: <String>[
      'lib/features/creator/ui/widgets/creator_entry_lists.dart',
      'lib/state/providers/task_provider.dart',
    ],
  ),
  'timeline': FeatureTestSpec(
    unitFiles: <String>['lib/features/timeline/ui/timeline_screen.dart'],
    integrationFiles: <String>[
      'lib/features/timeline/ui/timeline_screen.dart',
      'lib/app/navigation_shell.dart',
    ],
  ),
  'trajectory_engine': FeatureTestSpec(
    unitFiles: <String>[
      'lib/features/trajectory_engine/ui/trajectory_engine_screen.dart',
      'lib/state/providers/momentum_engine_provider.dart',
    ],
    integrationFiles: <String>[
      'lib/features/trajectory_engine/ui/trajectory_engine_screen.dart',
      'lib/features/nexus/ui/nexus_screen.dart',
    ],
  ),
  'tutorial': FeatureTestSpec(
    unitFiles: <String>[
      'lib/tutorial/tutorial_provider.dart',
      'lib/tutorial/tutorial_repository.dart',
    ],
    integrationFiles: <String>[
      'lib/tutorial/tutorial_overlay.dart',
      'lib/tutorial/tutorial_controller.dart',
    ],
  ),
  'ui': FeatureTestSpec(
    unitFiles: <String>[
      'lib/ui/widgets/offline_banner.dart',
      'lib/ui/widgets/smart_pressable.dart',
    ],
    integrationFiles: <String>[
      'lib/ui/layout/animated_system_background.dart',
      'lib/app/navigation_shell.dart',
    ],
  ),
};

final RegExp _implementationPattern = RegExp(
  r'(class\s+\w+|enum\s+\w+|mixin\s+\w+|extension\s+\w+|typedef\s+\w+|final\s+\w+Provider\b|Provider<|StateNotifier|Future<|Stream<|Widget build\()',
  multiLine: true,
);

final RegExp _integrationPattern = RegExp(
  r'(StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|Scaffold|MaterialApp|GoRoute|Widget build\(|Navigator\.|showDialog|ref\.watch\(|ref\.read\(|Provider<|StateNotifierProvider<|FutureProvider<|StreamProvider<)',
  multiLine: true,
);

final RegExp _backupImportPattern = RegExp(r'''import ['"][^'"]+\.bak''');

String _normalizePath(String relativePath) {
  return relativePath.replaceAll('/', Platform.pathSeparator);
}

FeatureTestSpec _specFor(String featureName) {
  final FeatureTestSpec? spec = _featureSpecs[featureName];
  if (spec == null) {
    throw ArgumentError.value(featureName, 'featureName', 'Unknown feature');
  }
  return spec;
}

String _readProjectFile(String relativePath) {
  final File file = File(_normalizePath(relativePath));
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Expected source file to exist: $relativePath',
  );
  return file.readAsStringSync();
}

void _expectFilesExist(List<String> relativePaths) {
  for (final String relativePath in relativePaths) {
    expect(
      File(_normalizePath(relativePath)).existsSync(),
      isTrue,
      reason: 'Expected source file to exist: $relativePath',
    );
  }
}

void _expectConcreteSource(String combinedSource, RegExp pattern, String kind) {
  expect(
    combinedSource.trim(),
    isNotEmpty,
    reason: '$kind source should not be empty.',
  );
  expect(
    pattern.hasMatch(combinedSource),
    isTrue,
    reason: '$kind source should contain concrete implementation markers.',
  );
  expect(
    _backupImportPattern.hasMatch(combinedSource),
    isFalse,
    reason: '$kind source should not import backup files.',
  );
  expect(
    combinedSource.toLowerCase().contains('placeholder'),
    isFalse,
    reason: '$kind source should not contain placeholder markers.',
  );
}

void defineFeatureUnitTests(String featureName) {
  final FeatureTestSpec spec = _specFor(featureName);

  group('$featureName unit coverage', () {
    test('unit source files exist', () {
      _expectFilesExist(spec.unitFiles);
    });

    test('unit source files contain real implementation code', () {
      final String combinedSource = spec.unitFiles
          .map(_readProjectFile)
          .join('\n');
      _expectConcreteSource(combinedSource, _implementationPattern, 'Unit');
    });

    test('unit source files are distinct production files', () {
      final Set<String> uniquePaths = spec.unitFiles.toSet();
      expect(uniquePaths.length, spec.unitFiles.length);
      for (final String path in uniquePaths) {
        expect(
          path.contains('.bak'),
          isFalse,
          reason: 'Unit path should not target backup files: $path',
        );
      }
    });
  });
}

void defineFeatureIntegrationTests(String featureName) {
  final FeatureTestSpec spec = _specFor(featureName);

  group('$featureName integration coverage', () {
    test('integration source files exist', () {
      _expectFilesExist(spec.integrationFiles);
    });

    test('integration source files contain real UI or wiring code', () {
      final String combinedSource = spec.integrationFiles
          .map(_readProjectFile)
          .join('\n');
      _expectConcreteSource(combinedSource, _integrationPattern, 'Integration');
    });

    test('integration source files are distinct production files', () {
      final Set<String> uniquePaths = spec.integrationFiles.toSet();
      expect(uniquePaths.length, spec.integrationFiles.length);
      for (final String path in uniquePaths) {
        expect(
          path.contains('.bak'),
          isFalse,
          reason: 'Integration path should not target backup files: $path',
        );
      }
    });
  });
}
