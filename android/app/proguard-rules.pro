# Keep Flutter embedding and generated plugin registration entry points.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Android entry points referenced directly from the manifest.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep Firebase and Billing integration classes used during startup and purchase flows.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-keep class com.android.billingclient.api.** { *; }

-dontwarn io.flutter.embedding.**
-dontwarn com.google.errorprone.annotations.**

# Preserve source file names and line numbers in crash stack traces.
# Without these, Crashlytics reports obfuscated traces with no line numbers.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Required for Gson deserialization used by flutter_local_notifications.
# Missing these can silently break reminder scheduling after a reboot.
-keepattributes Signature,InnerClasses,EnclosingMethod
