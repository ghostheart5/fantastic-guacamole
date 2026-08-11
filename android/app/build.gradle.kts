import java.util.Properties
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Base64
import java.util.Locale

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val productionApplicationId = "com.ghostheart5.chronospark"
val buildProfile = (
    (project.findProperty("CHRONOSPARK_BUILD_PROFILE") as String?)
        ?: System.getenv("CHRONOSPARK_BUILD_PROFILE")
        ?: "production"
)
    .trim()
    .lowercase(Locale.US)
val profileApplicationIds = mapOf(
    "production" to productionApplicationId,
    "staging" to "$productionApplicationId.staging",
    "maestro" to "$productionApplicationId.maestro",
)
val releaseApplicationId =
    (project.findProperty("CHRONOSPARK_APPLICATION_ID") as String?)
        ?.takeIf { buildProfile == "production" }
        ?: profileApplicationIds[buildProfile]
        ?: error("Unsupported CHRONOSPARK_BUILD_PROFILE '$buildProfile'. Use production, staging, or maestro.")
val googleServicesJsonFile = project.file("google-services.json")
val hasGoogleServicesJson = googleServicesJsonFile.exists() && buildProfile == "production"
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.lowercase(Locale.US).contains("release")
}

fun decodeDartDefines(rawDefines: String?): Map<String, String> =
    rawDefines
        .orEmpty()
        .split(',')
        .mapNotNull { encoded ->
            if (encoded.isBlank()) {
                return@mapNotNull null
            }

            val decoded = runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.recoverCatching {
                String(Base64.getUrlDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull() ?: return@mapNotNull null

            val separator = decoded.indexOf('=')
            if (separator <= 0) {
                return@mapNotNull null
            }
            decoded.substring(0, separator) to decoded.substring(separator + 1)
        }
        .toMap()

fun readEnvironmentAsset(file: File): Map<String, String> =
    file.readLines()
        .map(String::trim)
        .filter { line -> line.isNotEmpty() && !line.startsWith('#') }
        .mapNotNull { line ->
            val separator = line.indexOf('=')
            if (separator <= 0) {
                null
            } else {
                line.substring(0, separator).trim() to line.substring(separator + 1).trim()
            }
        }
        .toMap()

if (isReleaseTaskRequested) {
    val dartDefines = decodeDartDefines(project.findProperty("dart-defines") as String?)
    val requiredDefines = mapOf(
        "CHRONOSPARK_APP_FLAVOR" to "prod",
        "CHRONOSPARK_ENFORCE_PROD_READINESS" to "true",
        "CHRONOSPARK_MAESTRO_MODE" to "false",
        "CHRONOSPARK_ENABLE_MOCK_LOGIN" to "false",
        "CHRONOSPARK_ENABLE_MOCK_MODE" to "false",
        "CHRONOSPARK_PAYWALL_DISABLED" to "false",
        "CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS" to "false",
    )
    val mismatchedDefines = requiredDefines.filter { (key, expected) ->
        dartDefines[key]?.trim()?.lowercase(Locale.US) != expected
    }.keys
    require(mismatchedDefines.isEmpty()) {
        "Release Dart defines are missing or unsafe: ${mismatchedDefines.sorted().joinToString()}."
    }

    val requiredNonEmptyDefines = setOf(
        "CHRONOSPARK_SUPABASE_URL",
        "CHRONOSPARK_SUPABASE_ANON_KEY",
        "CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT",
        "CHRONOSPARK_AI_PROXY_ENDPOINT",
        "CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT",
        "CHRONOSPARK_ANDROID_SHA256_CERT",
    )
    val emptyDefines = requiredNonEmptyDefines.filter { key ->
        dartDefines[key].isNullOrBlank()
    }
    require(emptyDefines.isEmpty()) {
        "Release Dart defines are missing values: ${emptyDefines.sorted().joinToString()}."
    }

    val environmentAsset = rootProject.file("../.env")
    require(environmentAsset.isFile) {
        "Release builds require a generated, sanitized .env asset."
    }
    val assetValues = readEnvironmentAsset(environmentAsset)
    val allowedAssetKeys = setOf(
        "CHRONOSPARK_SUPABASE_URL",
        "CHRONOSPARK_SUPABASE_ANON_KEY",
    )
    val unexpectedAssetKeys = assetValues.keys.filter { key ->
        key.startsWith("CHRONOSPARK_") && key !in allowedAssetKeys
    }
    require(unexpectedAssetKeys.isEmpty()) {
        "Release .env contains forbidden runtime overrides: ${unexpectedAssetKeys.sorted().joinToString()}."
    }
    val divergentAssetKeys = allowedAssetKeys.filter { key ->
        assetValues[key].isNullOrBlank() || assetValues[key] != dartDefines[key]
    }
    require(divergentAssetKeys.isEmpty()) {
        "Release .env does not match its Dart defines: ${divergentAssetKeys.sorted().joinToString()}."
    }
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
    namespace = productionApplicationId
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = releaseApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(flutter.targetSdkVersion, 35)
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
            require(!isReleaseTaskRequested || buildProfile == "production") {
                "Release builds must use CHRONOSPARK_BUILD_PROFILE=production."
            }
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
    implementation("androidx.window:window:1.5.1")
    implementation("androidx.window:window-java:1.5.1")
    implementation("com.android.billingclient:billing:8.0.0")
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
