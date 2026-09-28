plugins {
    id("org.jetbrains.kotlin.multiplatform")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
    iosX64()
    iosArm64()
    iosSimulatorArm64()

    cocoapods {
        summary = "BitChord shared module"
        homepage = "https://github.com/kushagrasinghx/BitChord"
        ios.deploymentTarget = "17.0"
        xcodeConfigurationToNativeBuildType["Release"] = framework {
            isStatic = false
            baseName = "BitChordShared"
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.6.1")
                implementation("io.ktor:ktor-client-core:3.0.3")
                implementation("io.ktor:ktor-client-content-negotiation:3.0.3")
                implementation("io.ktor:ktor-serialization-kotlinx-json:3.0.3")
                implementation("io.ktor:ktor-client-darwin:3.0.3")
                implementation("io.ktor:ktor-client-logging:3.0.3")
                implementation("com.github.TeamNewPipe:nanojson:e9d656ddb49a412a5a0a5d5ef20ca7ef09549996")
                implementation("org.jsoup:jsoup:1.22.2")
                implementation("com.google.protobuf:protobuf-kotlin:4.35.0")
                implementation("org.mozilla:rhino:1.8.1")
                implementation("io.github.dokar3:quickjs-kt-core:1.0.5")
                implementation("androidx.palette:palette-ktx:1.0.0")
            }
        }
        val androidMain by getting {
            dependencies {
                implementation("androidx.core:core-ktx:1.15.0")
                implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
                implementation("androidx.security:security-crypto:1.1.0-alpha06")
                implementation("io.ktor:ktor-client-okhttp:3.0.3")
                implementation("com.microsoft.onnxruntime:onnxruntime-android:1.28.0")
                implementation("androidx.media3:media3-exoplayer:1.11.0")
                implementation("androidx.media3:media3-session:1.11.0")
                implementation("androidx.media3:media3-datasource-okhttp:1.11.0")
            }
        }
        val iosMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-darwin:3.0.3")
            }
        }
    }
}

android {
    namespace = "com.music.bitchord.shared"
    compileSdk = 36
    defaultConfig {
        minSdk = 26
        targetSdk = 36
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