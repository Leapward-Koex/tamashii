group = "com.leapwardkoex.tamashii.network_cost"
version = "0.1.0"

plugins {
    id("com.android.library")
}

android {
    namespace = "com.leapwardkoex.tamashii.network_cost"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 31
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
