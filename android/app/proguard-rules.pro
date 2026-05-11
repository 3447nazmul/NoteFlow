# ──────────────────────────────────────────────────────────────
# NoteFlow — ProGuard / R8 Rules
#
# These rules protect the release build against reverse
# engineering while preserving Flutter and Firebase functionality.
# ──────────────────────────────────────────────────────────────

# ── Flutter engine ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Google Sign-In ──
-keep class com.google.android.gms.auth.** { *; }

# ── Hive (local storage) ──
-keep class ** extends com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ── Flutter Secure Storage ──
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Gson / JSON (used by some plugins) ──
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── General safety ──
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
