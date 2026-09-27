pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
            }
            val flutterSdkPath =
                properties.getProperty("flutter.sdk")
                    ?: System.getenv("FLUTTER_ROOT")
                    ?: error("Set flutter.sdk in local.properties or configure FLUTTER_ROOT.")
            require(flutterSdkPath.isNotBlank()) {
                "The Flutter SDK path must not be blank."
            }
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
