plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.rani.tofy"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.rani.tofy"
        minSdk = 26
        targetSdk = 36
        // versionName = the iOS marketing version; versionCode = iOS build × 10 + an
        // Android-only respin digit (distribution/play-store/release-checklist-android.md).
        versionCode = 2090
        versionName = "2026.10.7"
        // ./gradlew assembleDebug -Pemu=true → a debug build wired to the LOCAL
        // Firebase emulators under the "demo-tofy" project (never production).
        buildConfigField("boolean", "USE_EMULATORS", (project.findProperty("emu") == "true").toString())
        // 10.0.2.2 is the host as seen from an AVD. A real device on the same
        // Wi-Fi needs the Mac's LAN address: -PemuHost=10.54.51.141
        buildConfigField("String", "EMULATOR_HOST", "\"${project.findProperty("emuHost") ?: "10.0.2.2"}\"")
    }

    // Upload key lives OUTSIDE the repo: ~/.tofy-keys/upload.jks, its password in
    // ~/.gradle/gradle.properties (TOFY_UPLOAD_*) and the macOS Keychain entry
    // "Tofy Android upload key". Play App Signing holds the real app key.
    signingConfigs {
        create("upload") {
            val f = project.findProperty("TOFY_UPLOAD_STORE_FILE") as String?
            if (f != null) {
                storeFile = file(f)
                storePassword = project.findProperty("TOFY_UPLOAD_STORE_PASSWORD") as String?
                keyAlias = project.findProperty("TOFY_UPLOAD_KEY_ALIAS") as String?
                keyPassword = project.findProperty("TOFY_UPLOAD_KEY_PASSWORD") as String?
            }
        }
    }

    buildTypes {
        release {
            if (project.findProperty("TOFY_UPLOAD_STORE_FILE") != null) signingConfig = signingConfigs.getByName("upload")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
}

// The kid screens pass the live, mutable ProgressEngine into composables. With
// strong skipping (on by default since Kotlin 2.0.20) an unchanged INSTANCE is
// skipped, so the home kept showing the old daily cap after the child doc
// arrived. Off = unstable params always recompose, which is what that code expects.
composeCompiler {
    featureFlags = setOf(org.jetbrains.kotlin.compose.compiler.gradle.ComposeFeatureFlag.StrongSkipping.disabled())
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-functions")

    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation("com.google.zxing:core:3.5.3")
    implementation("com.journeyapps:zxing-android-embedded:4.3.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
    // 📍 Location: fused location + geofences (child device); the family map
    // (parent) on OpenStreetMap — no API key, nothing to enable in a console.
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("org.osmdroid:osmdroid-android:6.1.20")

    // Google Play Billing (billing/): Tofy+, question packs / world passes, 💎 packs.
    implementation("com.android.billingclient:billing-ktx:8.0.0")
    // 🧒🚫 Google's age range before a device becomes a parent device (AgeGate.kt).
    implementation("com.google.android.play:age-signals:0.0.4")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
