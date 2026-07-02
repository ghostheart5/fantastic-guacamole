import java.util.Properties

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
    compileSdk = maxOf(flutter.compileSdkVersion, 34)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = releaseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(flutter.targetSdkVersion, 34)
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
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.android.billingclient:billing:6.0.1")
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
