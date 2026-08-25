pluginManagement {
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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

// Thermion 0.5.0-pre.5 still applies the legacy Kotlin Android plugin and
// pins AGP 7.3 inside its package. Keep the immutable renderer source pin, but
// evaluate the plugin with AVARRA's AGP 9 compatibility build instead.
val thermionFlutterProject = project(":thermion_flutter")
val thermionCompatibilityBuildFile =
    file("gradle/thermion_flutter_compat.gradle").absoluteFile.normalize()
thermionFlutterProject.buildFileName =
    thermionCompatibilityBuildFile.relativeTo(thermionFlutterProject.projectDir).path

include(":app")
