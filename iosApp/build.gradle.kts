plugins {
    id("org.jetbrains.kotlin.multiplatform")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.android.application")
}

kotlin {
    iosX64()
    iosArm64()
    iosSimulatorArm64()

    cocoapods {
        version = "1.0"
        summary = "BitChord iOS App"
        homepage = "https://github.com/kushagrasinghx/BitChord"
        ios.deploymentTarget = "17.0"
        pod("Firebase/Core") // optional, for analytics
    }

    sourceSets {
        val iosMain by getting {
            dependencies {
                implementation(project(":shared"))
                implementation(compose.bom)
                implementation("androidx.compose.ui:ui")
                implementation("androidx.compose.material3:material3")
                implementation("androidx.compose.foundation:foundation")
                implementation("androidx.activity:activity-compose:1.9.3")
                implementation("androidx.navigation:navigation-compose:2.8.5")
                implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
                implementation("io.coil-kt.coil3:coil-compose:3.0.4")
                implementation("dev.chrisbanes.haze:haze:1.3.1")
            }
        }
    }
}

android {
    namespace = "com.music.bitchord"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.music.bitchord"
        minSdk = 26
        targetSdk = 36
        versionCode = 17
        versionName = "1.6"
    }
    buildFeatures {
        compose = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        freeCompilerArgs += listOf("-Xopt-in=kotlinx.coroutines.ExperimentalCoroutinesApi")
    }
}