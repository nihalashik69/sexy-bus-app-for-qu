pluginManagement {
    val flutterSdkPath: String? = run {
        val properties = java.util.Properties()
        val localPropsFile = file("local.properties")
        if (localPropsFile.exists()) {
            localPropsFile.inputStream().use { properties.load(it) }
        }
        // Prefer local.properties flutter.sdk, fallback to FLUTTER_ROOT env var
        val raw = properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
        if (raw == null) {
            null
        } else {
            // Normalize path: unescape double backslashes and convert to system separators
            val unescaped = raw.replace("\\\\", "\\")
            // Try both unescaped and forward-slash variants (Windows paths)
            val candidates = listOf(unescaped, unescaped.replace('\\', '/'))
            candidates.firstOrNull { candidate ->
                val gradleDir = file("${'$'}candidate/packages/flutter_tools/gradle")
                gradleDir.exists()
            } ?: raw // return raw if no candidate exists (will be checked later)
        }
    }

    if (flutterSdkPath != null) {
        val flutterGradle = file("${'$'}flutterSdkPath/packages/flutter_tools/gradle")
        if (flutterGradle.exists()) {
            includeBuild(flutterGradle.absolutePath)
        } else {
            // Try an absolute fallback (useful when local.properties contains escaped values)
            val fallback = file("C:/Users/Admin/Desktop/Temporary Storage/flutter/packages/flutter_tools/gradle")
            if (fallback.exists()) {
                includeBuild(fallback.absolutePath)
            } else {
                println("Warning: Flutter gradle plugin not found at ${'$'}flutterGradle -- continuing without includeBuild")
            }
        }
    } else {
        println("Warning: flutter.sdk not set in local.properties and FLUTTER_ROOT not set -- continuing without includeBuild")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Fallback for Flutter hosted artifacts
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
