import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Closes every route that was pushed with `Navigator.push`, `showDialog` or
/// `showModalBottomSheet` on top of the router's first route.
///
/// Every shell route shares one page key, so `router.go` updates the page
/// beneath such a route in place and the pushed route would keep covering the
/// destination. Does nothing when only the first route is present.
void popToFirstRoute(BuildContext context) {
  Navigator.maybeOf(
    context,
    rootNavigator: true,
  )?.popUntil((Route<dynamic> route) => route.isFirst);
}

/// Navigates to [routePath] with the router found from [context] and returns
/// true, or returns false without side effects when there is no router.
///
/// Routes pushed on top of the first route are closed first, so the
/// destination is what the person sees afterwards.
bool goToAppRoutePath(BuildContext context, String routePath) {
  final GoRouter router;
  try {
    router = GoRouter.of(context);
  } on Object {
    return false;
  }
  popToFirstRoute(context);
  // An explicit destination must also clear imperative callback/redirect
  // matches. The reported URI alone does not describe that route stack.
  router.go(routePath);
  return true;
}

/// Opens [view] and closes any screen, dialog or sheet pushed above the first
/// route. When nothing is pushed it behaves exactly like `router.go`.
void goToAppView(BuildContext context, WidgetRef ref, AppView view) {
  try {
    if (goToAppRoutePath(context, routePathForAppView(view))) return;
  } on Object {
    // Some widget tests and local previews mount feature widgets without a
    // GoRouter. Only those router-less harnesses use the compatibility state.
  }
  ref.read(appFlowProvider.notifier).show(view);
}

/// The primary view Activity was opened from, or null when it was opened any
/// other way (tools list, profile, deep link, redirect).
///
/// While set, the shell keeps that view's tab bar visible with Activity shown
/// over it, and Back returns to that view. The shell clears it as soon as the
/// person is anywhere other than Activity.
final activityOriginProvider =
    NotifierProvider<ActivityOriginController, AppView?>(
      ActivityOriginController.new,
    );

class ActivityOriginController extends Notifier<AppView?> {
  @override
  AppView? build() => null;

  void set(AppView? origin) => state = origin;
}

/// Opens Activity from the primary view [origin] so that view's navigation
/// stays visible and Back returns to it.
void openActivityFrom(BuildContext context, WidgetRef ref, AppView origin) {
  ref.read(activityOriginProvider.notifier).set(origin);
  goToAppView(context, ref, AppView.progression);
}
