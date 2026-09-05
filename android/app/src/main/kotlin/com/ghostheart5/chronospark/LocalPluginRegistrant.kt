package com.ghostheart5.chronospark

import io.flutter.embedding.engine.FlutterEngine

/**
 * Registers the native capabilities supported by the offline production build.
 * Firebase Analytics initializes in onAttachedToEngine, before Dart runs, so
 * cloud plugins must never be registered and then removed after attachment.
 * Keep this allowlist aligned with the pinned plugin metadata when upgrading.
 */
internal object LocalPluginRegistrant {
    fun registerWith(engine: FlutterEngine) {
        engine.plugins.add(com.llfbandit.app_links.AppLinksPlugin())
        engine.plugins.add(com.ryanheise.audio_session.AudioSessionPlugin())
        engine.plugins.add(xyz.luan.audioplayers.AudioplayersPlugin())
        engine.plugins.add(dev.fluttercommunity.plus.connectivity.ConnectivityPlugin())
        engine.plugins.add(dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin())
        engine.plugins.add(com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin())
        engine.plugins.add(com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin())
        engine.plugins.add(net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin())
        engine.plugins.add(com.github.dart_lang.jni.JniPlugin())
        engine.plugins.add(com.github.dart_lang.jni_flutter.JniFlutterPlugin())
        engine.plugins.add(dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin())
        engine.plugins.add(com.baseflow.permissionhandler.PermissionHandlerPlugin())
        engine.plugins.add(dev.fluttercommunity.plus.share.SharePlusPlugin())
        engine.plugins.add(io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin())
        engine.plugins.add(io.flutter.plugins.urllauncher.UrlLauncherPlugin())
    }
}
