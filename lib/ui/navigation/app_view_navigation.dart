import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void goToAppView(BuildContext context, WidgetRef ref, AppView view) {
  try {
    final String routePath = routePathForAppView(view);
    final GoRouter router = GoRouter.of(context);
    if (router.routeInformationProvider.value.uri.path != routePath) {
      router.go(routePath);
    }
    return;
  } on Object {
    // Some widget tests and local previews mount feature widgets without a
    // GoRouter. Only those router-less harnesses use the compatibility state.
  }
  ref.read(appFlowProvider.notifier).show(view);
}
