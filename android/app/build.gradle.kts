import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val googleServicesJsonFile = project.file("google-services.json")
val hasGoogleServicesJson = googleServicesJsonFile.exists()

// Detect whether this is a release build so we can gate Firebase config.
// isReleaseBuild is true when the Gradle task list includes any Release task,
// which covers assembleRelease, bundleRelease, and their variants.
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (hasGoogleServicesJson) {
    // Apply Firebase plugins only when Android firebase config is available.
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else if (isReleaseBuild) {
    // Release builds without google-services.json ship without Crashlytics.
    // With minification on, any crash that does reach you will be unreadable.
    // Fail loudly here so the missing config is caught before the artifact
    // is uploaded rather than after it ships silently broken.
    error(
        "google-services.json is required for release builds. " +
            "Ensure the ANDROID_GOOGLE_SERVICES_JSON_BASE64 secret is set in CI " +
            "and the file is decoded before Gradle runs.",
    )
} else {
    logger.lifecycle(
        "google-services.json was not found at ${googleServicesJsonFile.path}. " +
            "Skipping Firebase Gradle plugins for this non-release build.",
    )
}

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

val releaseApplicationId =
    (project.findProperty("CHRONOSPARK_APPLICATION_ID") as String?)
        ?: "com.ghostheart5.chronospark"

val releaseVersionCode =
    (project.findProperty("CHRONOSPARK_VERSION_CODE") as String?)?.toIntOrNull()
        ?: flutter.versionCode

val releaseVersionName =
    (project.findProperty("CHRONOSPARK_VERSION_NAME") as String?)
        ?: flutter.versionName

fun Properties.hasReleaseSigningValues(): Boolean {
    val storePassword = getProperty("storePassword")?.trim().orEmpty()
    val keyPassword = getProperty("keyPassword")?.trim().orEmpty()
    val keyAlias = getProperty("keyAlias")?.trim().orEmpty()
    val storeFile = getProperty("storeFile")?.trim().orEmpty()

    return listOf(storePassword, keyPassword, keyAlias, storeFile).all { value ->
        value.isNotEmpty() && !value.startsWith("YOUR_")
    }
}

android {
    namespace = releaseApplicationId
    // Google Play requires API 36 for new submissions and updates starting
    // 2026-08-31. Keep the floor explicit so a stale Flutter toolchain cannot
    // silently produce a noncompliant release artifact.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = releaseApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(flutter.targetSdkVersion, 36)
        versionCode = releaseVersionCode
        versionName = releaseVersionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && keystoreProperties.hasReleaseSigningValues()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            val releaseSigningConfig = signingConfigs.findByName("release")

            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
            } else if (isReleaseBuild) {
                error(
                    "Release signing is not configured. Populate android/key.properties with the upload keystore values before building a Play bundle.",
                )
            } else {
                logger.lifecycle(
                    "Release signing is not configured. Continuing because this is not a release build.",
                )
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    // Billing Library version is intentionally NOT pinned here.
    // in_app_purchase_android manages its own billing dependency; an explicit
    // pin either duplicates or overrides what the plugin expects, which can
    // cause a Play upload rejection (v6 is below the v7+ floor) or a
    // runtime NoSuchMethodError in release builds only.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
