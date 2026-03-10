# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep FlutterSecureStorage internals
-keep class com.it_nomads.flutterSecureStorage.** { *; }

# Keep sqflite
-keep class com.tekartik.sqflite.** { *; }
