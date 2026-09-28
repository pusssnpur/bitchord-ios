plugins {
    id("org.jetbrains.kotlin.multiplatform") version "2.0.20" apply false
    id("com.android.application") version "8.5.0" apply false
    id("com.android.library") version "8.5.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.20" apply false
    id("com.github.johnrengelman.shadow") version "8.1.1" apply false
}

allprojects {
    group = "com.music.bitchord"
    version = "1.6.0"
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}