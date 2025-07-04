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
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyBDYktICoX43NTFeVZKSsfjcy2cX1x4zLY',
    appId: '1:442196446312:web:6533a03f4d5c2190553fdd',
    messagingSenderId: '442196446312',
    projectId: 'budget-zen-91391',
    authDomain: 'budget-zen-91391.firebaseapp.com',
    storageBucket: 'budget-zen-91391.firebasestorage.app',
    measurementId: 'G-B52BKZNYWC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC3KunSpr3aotNcvEqntCnG2YB2yUElggs',
    appId: '1:442196446312:android:a3afc8592b29e6e9553fdd',
    messagingSenderId: '442196446312',
    projectId: 'budget-zen-91391',
    storageBucket: 'budget-zen-91391.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA3VRACfjWJ3mNTZt5BjSabTbXYs4lZISc',
    appId: '1:442196446312:ios:71fb39ec6c68fc0b553fdd',
    messagingSenderId: '442196446312',
    projectId: 'budget-zen-91391',
    storageBucket: 'budget-zen-91391.firebasestorage.app',
    androidClientId: '442196446312-g7lhooui9o3fel6sm4f1a2vsfsp3ug95.apps.googleusercontent.com',
    iosClientId: '442196446312-0rn3423m7g9t30rs8sj230nr7f17onli.apps.googleusercontent.com',
    iosBundleId: 'com.example.budgetzen',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA3VRACfjWJ3mNTZt5BjSabTbXYs4lZISc',
    appId: '1:442196446312:ios:71fb39ec6c68fc0b553fdd',
    messagingSenderId: '442196446312',
    projectId: 'budget-zen-91391',
    storageBucket: 'budget-zen-91391.firebasestorage.app',
    androidClientId: '442196446312-g7lhooui9o3fel6sm4f1a2vsfsp3ug95.apps.googleusercontent.com',
    iosClientId: '442196446312-0rn3423m7g9t30rs8sj230nr7f17onli.apps.googleusercontent.com',
    iosBundleId: 'com.example.budgetzen',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBDYktICoX43NTFeVZKSsfjcy2cX1x4zLY',
    appId: '1:442196446312:web:e01fdb19d8020650553fdd',
    messagingSenderId: '442196446312',
    projectId: 'budget-zen-91391',
    authDomain: 'budget-zen-91391.firebaseapp.com',
    storageBucket: 'budget-zen-91391.firebasestorage.app',
    measurementId: 'G-5DBRCLFDL3',
  );
}
