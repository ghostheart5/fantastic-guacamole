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
// Keep this list aligned with AGP/Gradle release assembly task names used in CI and local builds.
val releaseTaskNames =
    setOf(
        "release",
        "assemblerelease",
        "bundlerelease",
        "packagerelease",
        "installrelease",
        "signreleasebundle",
        "publishreleasebundle",
    )
val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    val leafTaskName = taskName.substringAfterLast(':').lowercase()
    leafTaskName in releaseTaskNames
}
// Keep this list aligned with the fields read in signingConfigs.release.
val requiredReleaseSigningKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
fun isBlankReleaseSigningValue(properties: Properties, key: String): Boolean {
    return (properties[key] as? String).isNullOrBlank()
}
fun hasValidReleaseStoreFile(storeFilePath: String?): Boolean {
    return !storeFilePath.isNullOrBlank() && file(storeFilePath).exists()
}

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
            val releaseStoreFilePath = keystoreProperties["storeFile"] as? String
            val hasValidStoreFile = hasValidReleaseStoreFile(releaseStoreFilePath)
            val hasCompleteReleaseSigning =
                keystorePropertiesFile.exists() &&
                    requiredReleaseSigningKeys.all { key ->
                        !isBlankReleaseSigningValue(keystoreProperties, key)
                    } &&
                    hasValidStoreFile

            if (isReleaseTaskRequested) {
                if (!keystorePropertiesFile.exists()) {
                    throw GradleException(
                        "Release signing is required. Missing ${keystorePropertiesFile.path}. " +
                            "Create android/key.properties with release keystore values."
                    )
                }

                val missingKeys = requiredReleaseSigningKeys.filter { key ->
                    isBlankReleaseSigningValue(keystoreProperties, key)
                }
                if (missingKeys.isNotEmpty()) {
                    throw GradleException(
                        "Release signing is required. Missing key.properties values: " +
                            missingKeys.joinToString(", ")
                    )
                }

                if (!hasValidStoreFile) {
                    throw GradleException(
                        "Release signing is required. Keystore file not found: ${releaseStoreFilePath ?: "unknown"}"
                    )
                }
                signingConfig = signingConfigs.getByName("release")
            } else if (hasCompleteReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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
