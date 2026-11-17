# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# Video Compress
-keep class com.example.video_compress.** { *; }
-keep class com.otaliastudios.transcoder.** { *; }
-dontwarn com.otaliastudios.transcoder.**

# Video Player
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn androidx.media3.**

# Google Maps & Play Services
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Callkit Incoming & Foreground Services
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-dontwarn com.hiennv.flutter_callkit_incoming.**

# Firebase & Push Notifications
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Network & Desugaring
-dontwarn java.time.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Anti-tamper & Obfuscation
-repackageclasses ''
-allowaccessmodification
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose
