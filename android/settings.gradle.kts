pluginManagement {
    val fdroidBuild = providers.gradleProperty("sometimeFlavor").orNull == "fdroid" ||
        gradle.startParameter.taskNames.any { it.contains("fdroid", ignoreCase = true) }

    if (fdroidBuild) {
        val metadataFile = rootDir.parentFile.resolve(".flutter-plugins-dependencies")
        check(metadataFile.isFile) {
            "Flutter plugin metadata is missing. Run flutter pub get before the F-Droid build."
        }
        val originalMetadata = metadataFile.readText()
        @Suppress("UNCHECKED_CAST")
        val metadata = groovy.json.JsonSlurper().parseText(originalMetadata) as MutableMap<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val plugins = metadata["plugins"] as MutableMap<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val androidPlugins = plugins["android"] as MutableList<MutableMap<String, Any?>>
        check(androidPlugins.removeAll { it["name"] == "in_app_purchase_android" }) {
            "The F-Droid build expected the in_app_purchase_android plugin metadata."
        }
        metadataFile.writeText(groovy.json.JsonOutput.toJson(metadata))
        gradle.buildFinished {
            metadataFile.writeText(originalMetadata)
        }
    }

    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
