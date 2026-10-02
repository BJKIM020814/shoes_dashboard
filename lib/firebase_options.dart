import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web Firebase options are not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDYv4HzxB2jhwG7Mo9a3To8mEMHbg_19Y',
    appId: '1:864946455276:android:48c5863e7b2b6ea5aa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    storageBucket: 'shoe-20260930.firebasestorage.app',
  );
  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCkjzrLuFc3j5RlOybqNFhi9fdgY_8o6YU',
    appId: '1:864946455276:ios:043a137bf59fa64faa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    storageBucket: 'shoe-20260930.firebasestorage.app',
    iosBundleId: 'com.example.bootcampTeamproject1',
  );
}
