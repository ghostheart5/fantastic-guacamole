// Dart SDK imports.
import 'dart:async';

// Package imports.
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DeepLinkState {
  const DeepLinkState({this.latestUri});

  final Uri? latestUri;

  DeepLinkState copyWith({Uri? latestUri}) {
    return DeepLinkState(latestUri: latestUri ?? this.latestUri);
  }
}

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _subscription;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  Uri? _latestUri;

  Uri? get latestUri => _latestUri;

  Future<void> initializeEarly() async {
    _appLinks ??= AppLinks();
    final AppLinks? appLinks = _appLinks;
    if (appLinks == null) {
      return;
    }

    // Capture cold-start deep link as early as possible.
    final Uri? initialLink = await appLinks.getInitialLink();
    if (initialLink != null && _isTrusted(initialLink)) {
      _latestUri ??= initialLink;
    }
    final Uri? initial = _latestUri;
    if (initial != null) {
      _controller.add(initial);
    }

    _subscription ??= appLinks.uriLinkStream.listen((Uri uri) {
      if (!_isTrusted(uri)) return;
      _latestUri = uri;
      _controller.add(uri);
    });
  }

  Stream<Uri> get links => _controller.stream;

  bool _isTrusted(Uri uri) {
    if (uri.scheme != 'https') return false;
    const Set<String> hosts = <String>{
      'chronospark.app',
      'www.chronospark.app',
      'ghostheart5.github.io',
    };
    return hosts.contains(uri.host.toLowerCase()) &&
        (uri.path == '/app' ||
            uri.path.startsWith('/app/') ||
            uri.path.startsWith('/fantastic-guacamole/app'));
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final DeepLinkService service = DeepLinkService.instance;
  ref.onDispose(service.dispose);
  return service;
});

final deepLinkStateProvider = StreamProvider<DeepLinkState>((ref) async* {
  final DeepLinkService service = ref.read(deepLinkServiceProvider);
  await service.initializeEarly();

  yield DeepLinkState(latestUri: service.latestUri);

  await for (final Uri uri in service.links) {
    yield DeepLinkState(latestUri: uri);
  }
});
