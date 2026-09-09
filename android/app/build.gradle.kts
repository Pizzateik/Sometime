import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    // Apply the Flutter plugin after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
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

gradle.taskGraph.whenReady {
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
    namespace = "eu.eikrose.sometime"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "eu.eikrose.sometime"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Read the app version from pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
