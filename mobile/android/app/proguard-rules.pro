# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# record (audio recording)
-keep class com.llfbandit.record.** { *; }

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Gson (usado internamente por vários plugins)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
