import 'dart:convert';
import 'dart:io';

void main() {
  final String? androidSha =
      Platform.environment['CHRONOSPARK_ANDROID_SHA256_CERT'];
  final String? iosTeamId = Platform.environment['CHRONOSPARK_IOS_TEAM_ID'];

  if (androidSha == null || androidSha.trim().isEmpty) {
    stderr.writeln(
      'Missing CHRONOSPARK_ANDROID_SHA256_CERT environment variable.',
    );
    exitCode = 1;
    return;
  }
  if (iosTeamId == null || iosTeamId.trim().isEmpty) {
    stderr.writeln('Missing CHRONOSPARK_IOS_TEAM_ID environment variable.');
    exitCode = 1;
    return;
  }

  final File assetlinksFile = File('web/.well-known/assetlinks.json');
  final File aasaFile = File('web/.well-known/apple-app-site-association');

  final List<Map<String, Object>> assetLinks = <Map<String, Object>>[
    <String, Object>{
      'relation': <String>['delegate_permission/common.handle_all_urls'],
      'target': <String, Object>{
        'namespace': 'android_app',
        'package_name': 'com.ghostheart5.chronospark',
        'sha256_cert_fingerprints': <String>[androidSha.trim()],
      },
    },
  ];

  final Map<String, Object> appleAppSiteAssociation = <String, Object>{
    'applinks': <String, Object>{
      'apps': <Object>[],
      'details': <Map<String, Object>>[
        <String, Object>{
          'appIDs': <String>['${iosTeamId.trim()}.com.ghostheart5.chronospark'],
          'paths': <String>['/app/*', '/fantastic-guacamole/app/*'],
        },
      ],
    },
  };

  assetlinksFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(assetLinks),
  );
  aasaFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(appleAppSiteAssociation),
  );

  stdout.writeln('Updated web/.well-known/assetlinks.json');
  stdout.writeln('Updated web/.well-known/apple-app-site-association');
}
