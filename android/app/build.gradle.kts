import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException(
            "Missing `$name` in ${keystorePropertiesFile.path}. " +
                "See android/key.properties.example.",
        )

fun defaultAndroidVersionCode(): Int {
    val baseEpochSeconds = 1_704_067_200L // 2024-01-01T00:00:00Z
    val nowSeconds = System.currentTimeMillis() / 1_000L
    return (nowSeconds - baseEpochSeconds).toInt()
}

val androidVersionCode = (
    System.getenv("ANDROID_VERSION_CODE")
        ?: project.findProperty("androidVersionCode") as String?
        ?: defaultAndroidVersionCode().toString()
).toInt()

val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

android {
    namespace = "com.leapwardkoex.tamashii"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = rootProject.file(requiredKeystoreProperty("storeFile"))
                storePassword = requiredKeystoreProperty("storePassword")
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.leapwardkoex.tamashii"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = androidVersionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }

        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseTaskRequested) {
                throw GradleException(
                    "Missing ${keystorePropertiesFile.path}. " +
                        "Copy android/key.properties.example to android/key.properties " +
                        "and fill in the release keystore values.",
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.guava:guava:32.0.1-jre")
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta1")
}
