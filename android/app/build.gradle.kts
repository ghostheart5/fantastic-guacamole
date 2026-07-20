import java.util.Properties
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Locale

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val googleServicesJsonFile = project.file("google-services.json")
val hasGoogleServicesJson = googleServicesJsonFile.exists()
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.lowercase(Locale.US).contains("release")
}

if (isReleaseTaskRequested && !hasGoogleServicesJson) {
    throw GradleException(
        "google-services.json is required for release builds at ${googleServicesJsonFile.path}",
    )
}

if (hasGoogleServicesJson) {
    // Apply Firebase plugins only when Android firebase config is available.
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.lifecycle(
        "google-services.json was not found at ${googleServicesJsonFile.path}. Skipping Firebase Gradle plugins for this build.",
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

fun String.normalizeFingerprint(): String =
    uppercase(Locale.US)
        .replace("SHA1:", "")
        .replace("SHA-1:", "")
        .replace(" ", "")
        .trim()

fun ByteArray.toHexFingerprint(): String = joinToString(":") { b -> "%02X".format(b) }

fun File.resolveAgainst(base: File): File = if (isAbsolute) this else File(base, path)

android {
    namespace = releaseApplicationId
    compileSdk = maxOf(flutter.compileSdkVersion, 34)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = releaseApplicationId
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
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            val releaseSigningConfig = signingConfigs.findByName("release")

            if (releaseSigningConfig != null) {
                val expectedUploadSha1 =
                    (project.findProperty("CHRONOSPARK_EXPECTED_UPLOAD_SHA1") as String?)
                        ?.takeIf { it.isNotBlank() }

                val storePath = keystoreProperties.getProperty("storeFile")
                    ?: error("android/key.properties is missing storeFile")
                val storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("android/key.properties is missing storePassword")
                val alias = keystoreProperties.getProperty("keyAlias")
                    ?: error("android/key.properties is missing keyAlias")

                val resolvedStoreFile = File(storePath).resolveAgainst(rootProject.projectDir)
                require(resolvedStoreFile.exists()) {
                    "Release keystore not found at ${resolvedStoreFile.path}. Ensure android/key.properties points to the Play upload keystore file."
                }

                val keyStore = KeyStore.getInstance("JKS").apply {
                    resolvedStoreFile.inputStream().use { input ->
                        load(input, storePassword.toCharArray())
                    }
                }
                val certificate = keyStore.getCertificate(alias)
                    ?: error("Key alias '$alias' was not found in ${resolvedStoreFile.path}")
                val actualSha1 = MessageDigest.getInstance("SHA-1")
                    .digest(certificate.encoded)
                    .toHexFingerprint()

                if (expectedUploadSha1 != null) {
                    require(actualSha1.normalizeFingerprint() == expectedUploadSha1.normalizeFingerprint()) {
                        "Upload key SHA-1 mismatch. Expected ${expectedUploadSha1.normalizeFingerprint()} but found ${actualSha1.normalizeFingerprint()}. Use the correct Play upload keystore before building release bundles."
                    }
                }

                signingConfig = releaseSigningConfig
            } else {
                error(
                    "Release signing is not configured. Populate android/key.properties with the upload keystore values before building a Play bundle.",
                )
            }
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
