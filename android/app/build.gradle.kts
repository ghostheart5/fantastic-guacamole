import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
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
val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}
val requiredReleaseSigningKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")

android {
    namespace = releaseApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = releaseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = releaseVersionCode
        versionName = releaseVersionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseTaskRequested) {
                if (!keystorePropertiesFile.exists()) {
                    throw GradleException(
                        "Release signing is required. Missing ${keystorePropertiesFile.path}. " +
                            "Create android/key.properties with release keystore values."
                    )
                }

                val missingKeys = requiredReleaseSigningKeys.filter { key ->
                    (keystoreProperties[key] as? String).isNullOrBlank()
                }
                if (missingKeys.isNotEmpty()) {
                    throw GradleException(
                        "Release signing is required. Missing key.properties values: " +
                            missingKeys.joinToString(", ")
                    )
                }

                val releaseStoreFilePath = keystoreProperties["storeFile"] as String
                if (!file(releaseStoreFilePath).exists()) {
                    throw GradleException(
                        "Release signing is required. Keystore file not found: $releaseStoreFilePath"
                    )
                }
            }

            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("com.android.billingclient:billing:6.0.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
