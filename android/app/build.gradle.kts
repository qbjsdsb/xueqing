import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}
val requireReleaseSigning = System.getenv("XUEQING_REQUIRE_RELEASE_SIGNING") == "true"
if (requireReleaseSigning && !signingPropertiesFile.exists()) {
    throw GradleException(
        "Release signing is required, but android/key.properties was not provided."
    )
}

android {
    namespace = "com.xueqing.app"
    // flutter_secure_storage currently requires Android API 37 to compile.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.xueqing.app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingPropertiesFile.exists()) {
            create("xueqingRelease") {
                keyAlias = signingProperties.getProperty("keyAlias")
                    ?: throw GradleException("Android signing keyAlias is missing.")
                keyPassword = signingProperties.getProperty("keyPassword")
                    ?: throw GradleException("Android signing keyPassword is missing.")
                storeFile = rootProject.file(
                    signingProperties.getProperty("storeFile")
                        ?: throw GradleException("Android signing storeFile is missing.")
                )
                storePassword = signingProperties.getProperty("storePassword")
                    ?: throw GradleException(
                        "Android signing storePassword is missing."
                    )
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingPropertiesFile.exists()) {
                signingConfigs.getByName("xueqingRelease")
            } else {
                // Debug signing remains available for local smoke builds only.
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core:1.15.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
