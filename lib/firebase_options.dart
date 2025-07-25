// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJG31ImuAQm21JF7CyjjtYhTbsU3c4yTs',
    appId: '1:1008163722435:web:43bb4b93edcecb8f413e76',
    messagingSenderId: '1008163722435',
    projectId: 'steps4perks',
    authDomain: 'steps4perks.firebaseapp.com',
    storageBucket: 'steps4perks.firebasestorage.app',
    measurementId: 'G-QD5GW1MEBG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBAzzm3qB3DN7vqS9gub3IMxE_O8Sjys8o',
    appId: '1:1008163722435:android:adae61116994a319413e76',
    messagingSenderId: '1008163722435',
    projectId: 'steps4perks',
    storageBucket: 'steps4perks.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCb8ds4if3sxsF7VXQ77Db7paS28HgZHAM',
    appId: '1:1008163722435:ios:8095ee479e723ac3413e76',
    messagingSenderId: '1008163722435',
    projectId: 'steps4perks',
    storageBucket: 'steps4perks.firebasestorage.app',
    iosBundleId: 'com.example.steps4perks',
  );

}