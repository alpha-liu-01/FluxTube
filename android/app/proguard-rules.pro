# Optimization settings
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''

# Flutter default ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# NewPipe Extractor
-keep class org.schabi.newpipe.extractor.** { *; }
-keepclassmembers class org.schabi.newpipe.extractor.** { *; }

# Mozilla Rhino JavaScript Engine (used by NewPipe for signature decryption)
-keep class org.mozilla.javascript.** { *; }
-keepclassmembers class org.mozilla.javascript.** { *; }
-dontwarn org.mozilla.javascript.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Jsoup and RE2J (regex engine used by jsoup)
-keep class org.jsoup.** { *; }
-keepclassmembers class org.jsoup.** { *; }
-dontwarn org.jsoup.**
-dontwarn com.google.re2j.**
-keep class com.google.re2j.** { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Keep data classes for JSON serialization
-keepclassmembers class lol.alphaliu01.gastube.newpipe.models.** { *; }

# Prevent R8 from removing classes needed at runtime
-keep class * extends java.lang.Exception

# Audio Service / Media Session
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# Android Notification classes
-keep class android.app.Notification { *; }
-keep class android.app.Notification$* { *; }
-keep class android.app.NotificationManager { *; }
-keep class android.app.NotificationChannel { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

# MediaMuxer Handler - Keep classes for video/audio muxing
-keep class lol.alphaliu01.gastube.MediaMuxerHandler { *; }
-keepclassmembers class lol.alphaliu01.gastube.MediaMuxerHandler { *; }

# Android Media APIs used by MediaMuxerHandler
-keep class android.media.MediaMuxer { *; }
-keep class android.media.MediaExtractor { *; }
-keep class android.media.MediaFormat { *; }
-keep class android.media.MediaCodec { *; }
-keep class android.media.MediaCodec$BufferInfo { *; }
-keepclassmembers class android.media.** { *; }

# Google Play Core (Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
