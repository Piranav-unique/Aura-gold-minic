# Flutter & Android Architecture
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Razorpay Android SDK (Required for Play Store release)
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*

# Biometric & Keystore Security
-keep class androidx.biometric.** { *; }
-keep class androidx.security.crypto.** { *; }

# Kotlin Coroutines & Serialization
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# Play Core & Flutter Deferred Components
-dontwarn com.google.android.play.core.**

-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
