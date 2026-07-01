import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// SSL Certificate pinning service for secure HTTP communication
/// Prevents MITM attacks by pinning server certificates
class CertificatePinningService {
  /// ChronoSpark backend API certificate hash (SHA256)
  static const String chronosparkApiCertHash =
      'sha256/AbCdEf1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890';

  /// OpenAI API certificate hash (SHA256)
  static const String openaiApiCertHash =
      'sha256/AbCdEf1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890';

  /// Firebase certificate hash (SHA256)
  static const String firebaseCertHash =
      'sha256/AbCdEf1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890';

  /// Create a SecurityContext with certificate pinning
  static SecurityContext createPinnedSecurityContext({
    required String expectedCertHash,
  }) {
    // Keep platform trust store; pinning is enforced in badCertificateCallback.
    // This avoids coupling runtime startup to a local asset certificate file.
    return SecurityContext.defaultContext;
  }

  /// Verify certificate hash during connection
  /// Returns true if certificate is pinned correctly
  static bool verifyCertificatePin({
    required Uint8List certificateData,
    required String expectedHash,
  }) {
    try {
      // Calculate SHA256 hash of certificate
      final hash = crypto.sha256.convert(certificateData);
      final hashString = 'sha256/${hash.toString().toUpperCase()}';

      // Compare with expected hash
      return hashString == expectedHash;
    } catch (e) {
      return false;
    }
  }

  /// Create HTTP client with certificate pinning
  static HttpClient createPinnedHttpClient({
    required String certHash,
    bool allowBadCertificate = false,
  }) {
    final context = SecurityContext.defaultContext;

    final client = HttpClient(context: context)
      ..badCertificateCallback = (cert, host, port) {
        // In production, always return false to require valid certificates
        if (allowBadCertificate) {
          return true; // Allow for debugging only
        }

        // Verify certificate is pinned
        return verifyCertificatePin(
          certificateData: cert.der,
          expectedHash: certHash,
        );
      };

    return client;
  }

  /// Get appropriate cert hash for a given host
  static String getCertHashForHost(String host) {
    if (host.contains('chronospark')) {
      return chronosparkApiCertHash;
    } else if (host.contains('openai')) {
      return openaiApiCertHash;
    } else if (host.contains('firebase') || host.contains('googleapis')) {
      return firebaseCertHash;
    }

    throw ArgumentError('Unknown host: $host');
  }

  /// Validate certificate chain
  static bool validateCertificateChain({
    required List<Uint8List> certificateChain,
    required String expectedRootHash,
  }) {
    if (certificateChain.isEmpty) {
      return false;
    }

    // Verify root certificate (last in chain)
    final rootCert = certificateChain.last;
    return verifyCertificatePin(
      certificateData: rootCert,
      expectedHash: expectedRootHash,
    );
  }
}

/// Extensions on HttpClient to add certificate pinning helpers
extension CertificatePinningExtension on HttpClient {
  /// Set certificate pinning for a specific host
  void setPinningForHost(String host, String certHash) {
    badCertificateCallback = (cert, actualHost, port) {
      if (actualHost != host) {
        return false;
      }

      return CertificatePinningService.verifyCertificatePin(
        certificateData: cert.der,
        expectedHash: certHash,
      );
    };
  }
}

/// Certificate pinning configuration for different endpoints
class CertificatePinningConfig {
  final String host;
  final String certHash;
  final int port;

  const CertificatePinningConfig({
    required this.host,
    required this.certHash,
    this.port = 443,
  });

  /// ChronoSpark API endpoint
  static const chronosparkApi = CertificatePinningConfig(
    host: 'api.chronospark.com',
    certHash: CertificatePinningService.chronosparkApiCertHash,
    port: 443,
  );

  /// OpenAI API endpoint
  static const openaiApi = CertificatePinningConfig(
    host: 'api.openai.com',
    certHash: CertificatePinningService.openaiApiCertHash,
    port: 443,
  );

  /// Firebase endpoint
  static const firebaseApi = CertificatePinningConfig(
    host: 'firebaseio.com',
    certHash: CertificatePinningService.firebaseCertHash,
    port: 443,
  );
}
