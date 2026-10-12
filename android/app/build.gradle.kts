import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis Play Store dibaca dari android/key.properties (tidak diunggah ke git).
// Lihat README bagian "Rilis Android". Jika belum ada, build rilis memakai kunci debug.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val punyaKunciRilis = keyProperties.getProperty("storeFile") != null

android {
    namespace = "id.assalafiyah.portalsalaf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.assalafiyah.portalsalaf"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Versi diambil dari pubspec.yaml (version: 1.0.0+1 → versionName 1.0.0, versionCode 1)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (punyaKunciRilis) {
            create("rilis") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (punyaKunciRilis) signingConfigs.getByName("rilis") else signingConfigs.getByName("debug")
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
