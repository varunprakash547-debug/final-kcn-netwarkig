import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux Firebase options are not configured.');
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia Firebase options are not configured.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIV_SnNcP2Ff59C0yQz9qBuyPVehkjbV0',
    appId: '1:250640412076:web:259fa3a869e5f5d43a5e09',
    messagingSenderId: '250640412076',
    projectId: 'kcn-production',
    authDomain: 'kcn-production.firebaseapp.com',
    storageBucket: 'kcn-production.firebasestorage.app',
    measurementId: 'G-0KRR57LVNM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCaLNfhwQxf9OChmzgqu0bo2ouXoOXPlfM',
    appId: '1:250640412076:android:156380862d8945cc3a5e09',
    messagingSenderId: '250640412076',
    projectId: 'kcn-production',
    storageBucket: 'kcn-production.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDqiIcMB3DlSc69rZ7vHKd-pit9o3m00D8',
    appId: '1:250640412076:ios:7a2a99f52a279e443a5e09',
    messagingSenderId: '250640412076',
    projectId: 'kcn-production',
    storageBucket: 'kcn-production.firebasestorage.app',
    iosClientId: '250640412076-qdq22aa94752jqb6kgmkoq0u6g46h7mk.apps.googleusercontent.com',
    iosBundleId: 'com.kcn.krishiCreditNetworkV2',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIV_SnNcP2Ff59C0yQz9qBuyPVehkjbV0',
    appId: '1:250640412076:web:13cd30d21efc4f953a5e09',
    messagingSenderId: '250640412076',
    projectId: 'kcn-production',
    authDomain: 'kcn-production.firebaseapp.com',
    storageBucket: 'kcn-production.firebasestorage.app',
    measurementId: 'G-14PK4XNYE3',
  );
}
