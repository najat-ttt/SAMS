import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class FirebaseConfig {
  // Private constructor to prevent instantiation
  FirebaseConfig._();

  // Configuration constants - these should be moved to environment variables in production
  static const Map<String, String> _config = {
    'apiKey': 'AIzaSyAZk-0O762ba30uaKg4Z8mKVD10cV0okoM',
    'projectId': 'sams8-3-2025',
    'storageBucket': 'sams8-3-2025.firebasestorage.app',
    'messagingSenderId': '241623526441',
    'authDomain': 'sams8-3-2025.firebaseapp.com',
  };

  // App IDs for different platforms
  static const Map<String, String> _appIds = {
    'web': '1:241623526441:web:af145909d6302fb64f8038',
    'windows': '1:241623526441:windows:af145909d6302fb64f8038',
    'android': '1:241623526441:android:af145909d6302fb64f8038',
  };

  // Get platform-specific Firebase options
  static FirebaseOptions getFirebaseOptions() {
    if (kIsWeb) {
      // Web-specific Firebase configuration
      return const FirebaseOptions(
        apiKey: "AIzaSyAZk-0O762ba30uaKg4Z8mKVD10cV0okoM",
        appId: "1:241623526441:web:af145909d6302fb64f8038",
        messagingSenderId: "241623526441",
        projectId: "sams8-3-2025",
        storageBucket: "sams8-3-2025.firebasestorage.app",
        authDomain: "sams8-3-2025.firebaseapp.com",
      );
    } else if (Platform.isWindows) {
      // Windows-specific Firebase configuration
      return const FirebaseOptions(
        apiKey: "AIzaSyAZk-0O762ba30uaKg4Z8mKVD10cV0okoM",
        appId: "1:241623526441:windows:af145909d6302fb64f8038",
        messagingSenderId: "241623526441",
        projectId: "sams8-3-2025",
        storageBucket: "sams8-3-2025.firebasestorage.app",
      );
    } else {
      // Default (Android/iOS) Firebase configuration
      return const FirebaseOptions(
        apiKey: "AIzaSyAZk-0O762ba30uaKg4Z8mKVD10cV0okoM",
        appId: "1:241623526441:android:af145909d6302fb64f8038",
        messagingSenderId: "241623526441",
        projectId: "sams8-3-2025",
        storageBucket: "sams8-3-2025.firebasestorage.app",
      );
    }
  }

  // Initialize Firebase with proper configuration
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: getFirebaseOptions(),
    );
  }
}
