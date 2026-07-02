import 'dart:math';

import 'package:fantastic_guacamole/features/identity/repositories/identity_repository.dart';

abstract class IdentityServiceContract {
  Future<String?> getIdentityId();
  Future<void> registerIdentity(String id);
  Future<String> ensureIdentity();
}

class IdentityService implements IdentityServiceContract {
  IdentityService(this._repository);

  final IdentityRepository _repository;

  @override
  Future<String?> getIdentityId() => _repository.getIdentityId();

  @override
  Future<void> registerIdentity(String id) => _repository.saveIdentityId(id);

  /// Returns the stored identity ID, generating and persisting one if absent.
  @override
  Future<String> ensureIdentity() async {
    final existing = await _repository.getIdentityId();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generateUuidV4();
    await _repository.saveIdentityId(id);
    return id;
  }

  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
}

class MockIdentityService implements IdentityServiceContract {
  MockIdentityService({required this.mockIdentity});

  final String mockIdentity;
  String? _current;

  @override
  Future<String?> getIdentityId() async {
    return _current ?? mockIdentity;
  }

  @override
  Future<void> registerIdentity(String id) async {
    _current = id.trim().isEmpty ? mockIdentity : id;
  }

  @override
  Future<String> ensureIdentity() async {
    _current ??= mockIdentity;
    return _current ?? mockIdentity;
  }
}
