// FCM Push Notification Registration
//
// SETUP REQUIRED (one-time):
//  1. Go to https://console.firebase.google.com → New Project → "DevOmnix VPN"
//  2. Add Android app → package name: check android/app/build.gradle for applicationId
//  3. Download google-services.json → place in android/app/
//  4. Add to pubspec.yaml dependencies:
//       firebase_core: ^3.0.0
//       firebase_messaging: ^15.0.0
//  5. Run: dart pub get
//  6. Uncomment all imports and code below.
//
// Until configured, this file is a no-op stub.

import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// TODO: uncomment after Firebase setup
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));

class FcmService {
  FcmService(this._ref);
  final Ref _ref;

  Future<void> init() async {
    // TODO: uncomment after Firebase setup
    // await Firebase.initializeApp();
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission();
    // final token = await messaging.getToken();
    // if (token != null) await _registerToken(token);
    // FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    try {
      final dio = _ref.read(backendDioProvider);
      await dio.post('/auth/fcm-token', data: {'fcm_token': token});
    } catch (_) {}
  }
}
