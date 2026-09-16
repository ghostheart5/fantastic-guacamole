import 'package:in_app_purchase_android/billing_client_wrappers.dart' as gp;
// in_app_purchase_android 0.5.2 exposes reconnectWithPendingPurchasesParams
// publicly but omits its parameter type from billing_client_wrappers.dart.
// Keep this single compatibility import isolated until upstream exports it.
// The architecture guard permits only this file/type and pins the version.
// ignore: implementation_imports
import 'package:in_app_purchase_android/src/billing_client_wrappers/pending_purchases_params_wrapper.dart';

typedef GooglePlayPendingParams = PendingPurchasesParamsWrapper;

Future<void> enableGooglePlayPrepaidPending(gp.BillingClientManager manager) =>
    manager.reconnectWithPendingPurchasesParams(
      const GooglePlayPendingParams(enablePrepaidPlans: true),
    );
