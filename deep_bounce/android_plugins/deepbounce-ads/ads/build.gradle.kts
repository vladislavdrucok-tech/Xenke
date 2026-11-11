plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginName = "DeepBounceAds"
val pluginPackageName = "com.deepbounce.ads"

// Keep these two in sync with addons/DeepBounceAds/export_plugin.gd (_get_android_dependencies)
val gmaVersion = "24.9.0"
val umpVersion = "3.2.0"

android {
    namespace = pluginPackageName
    compileSdk = 35

    buildFeatures { buildConfig = true }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"${pluginName}\"")
        setProperty("archivesBaseName", pluginName)
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    compileOnly("org.godotengine:godot:4.5.1.stable")
    implementation("com.google.android.gms:play-services-ads:$gmaVersion")
    implementation("com.google.android.ump:user-messaging-platform:$umpVersion")
}

val copyAars by tasks.registering(Copy::class) {
    from("build/outputs/aar")
    include("$pluginName-release.aar", "$pluginName-debug.aar")
    into(rootProject.file("../../addons/$pluginName/bin"))
}
tasks.named("assemble").configure { finalizedBy(copyAars) }
