# Tofy (com.rani.tofy) — R8 rules for the release build.
#
# Most libraries ship their own consumer rules inside the AAR/JAR and need
# nothing here: Firebase (Auth, Firestore, Messaging, Functions), Compose,
# AndroidX, Coil, zxing-android-embedded, and kotlinx-serialization (1.5+
# bundles its rules in META-INF). What is below is only what they don't cover.
# Background: docs/play-store/release-checklist-android.md.

# ── Crash reports from Play Console: keep file/line info, hide the source name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Credential Manager (Google sign-in). The play-services provider is loaded
#    by reflection from androidx.credentials — Google's documented rule.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

# ── kotlinx-serialization: our @Serializable models (content banks, persisted
#    kid state, learning history). The library's bundled rules already keep the
#    generated serializers; these keep the companion lookups explicit for R8
#    full mode (AGP 8 default) on our own package.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers @kotlinx.serialization.Serializable class com.rani.tofy.** {
    static ** Companion;
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclassmembers class com.rani.tofy.**$$serializer { *; }
-keepclasseswithmembers class com.rani.tofy.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ── Components referenced only from XML (manifest / accessibility config).
#    AAPT generates keep rules for these already; listed so a rename never
#    silently breaks the guard that Play reviewed.
-keep class com.rani.tofy.kid.enforce.TofyGuardService { <init>(); }
-keep class com.rani.tofy.push.TofyMessagingService { <init>(); }

# ── Firestore: we never use toObject()/POJO mapping (every read is a Map via
#    data/Fields.kt), so no model classes need keeping. If that ever changes,
#    add: -keep class com.rani.tofy.data.** { *; }

# ── zxing core is pure Java with no reflection; the embedded scanner's
#    CaptureActivity is kept by its own manifest entry.
-dontwarn com.google.zxing.**
