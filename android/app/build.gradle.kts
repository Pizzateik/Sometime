import java.util.Properties
import java.io.File
import org.gradle.api.tasks.compile.JavaCompile
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    // Apply the Flutter plugin after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("androidx.core:core:1.13.1")
}

val releaseProperties = Properties()
val releasePropertiesFile = System.getenv("SOMETIME_SIGNING_PROPERTIES")
    ?.takeIf { it.isNotBlank() }
    ?.let(::File)
    ?: File(System.getProperty("user.home"), ".sometime-signing/key.properties")
val requiredReleaseProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
if (releasePropertiesFile.isFile) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val hasReleaseProperties = releasePropertiesFile.isFile &&
    requiredReleaseProperties.all { !releaseProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFile = releaseProperties.getProperty("storeFile")?.let(::File)
val fdroidBuild = providers.gradleProperty("sometimeFlavor").orNull == "fdroid" ||
    gradle.startParameter.taskNames.any { it.contains("fdroid", ignoreCase = true) }

gradle.taskGraph.whenReady {
    if (fdroidBuild) return@whenReady
    val releaseRequested = allTasks.any {
        it.project == project && it.name.contains("release", ignoreCase = true)
    }
    if (!releaseRequested) return@whenReady
    if (!releasePropertiesFile.isFile) {
        throw GradleException(
            "Sometime release signing configuration not found. " +
                "Expected SOMETIME_SIGNING_PROPERTIES or ~/.sometime-signing/key.properties.",
        )
    }
    val missing = requiredReleaseProperties.filter {
        releaseProperties.getProperty(it).isNullOrBlank()
    }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Sometime release signing configuration is incomplete. Missing: ${missing.joinToString()}.",
        )
    }
    if (releaseStoreFile?.isFile != true) {
        throw GradleException("Sometime release upload keystore was not found at the configured path.")
    }
}

android {
    namespace = "de.eikrose.sometime"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.eikrose.sometime"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Read the app version from pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "distribution"

    productFlavors {
        create("play") {
            dimension = "distribution"
        }
        create("fdroid") {
            dimension = "distribution"
        }
    }

    signingConfigs {
        if (hasReleaseProperties) {
            create("release") {
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = releaseProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (fdroidBuild) {
                // F-Droid signs the APK produced from source with its own key.
                null
            } else {
                signingConfigs.findByName("release")
            }
        }
    }

}

val abiVersionCodes = mapOf(
    "armeabi-v7a" to 1,
    "arm64-v8a" to 2,
    "x86_64" to 3,
)

android.applicationVariants.configureEach {
    val variant = this
    outputs.forEach { output ->
        val abiVersionCode = output.filters
            .firstOrNull { it.filterType == "ABI" }
            ?.identifier
            ?.let(abiVersionCodes::get)
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

if (fdroidBuild) {
    tasks.withType<JavaCompile>().configureEach {
        exclude("io/flutter/plugins/GeneratedPluginRegistrant.java")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
    if (fdroidBuild) {
        target = "lib/main_fdroid.dart"
    }
}
