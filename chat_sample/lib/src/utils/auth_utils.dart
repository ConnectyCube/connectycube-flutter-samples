import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../../firebase_options.dart';

Future<CubeSession> createPhoneAuthSession() async {
  var phoneAuthIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (phoneAuthIdToken == null) {
    return createSession();
  }

  return createSessionUsingSocialProvider(
    CubeProvider.FIREBASE_PHONE,
    DefaultFirebaseOptions.currentPlatform.projectId,
    phoneAuthIdToken,
  ).then((_) {
    return CubeSessionManager.instance.activeSession!;
  });
}

Future<CubeSession> createFacebookAuthSession() async {
  final AccessToken? accessToken = await FacebookAuth.instance.accessToken;
  if (accessToken == null) {
    return createSession();
  }

  return createSessionUsingSocialProvider(
    CubeProvider.FACEBOOK,
    accessToken.token,
  ).then((_) {
    return CubeSessionManager.instance.activeSession!;
  });
}

Future<CubeSession> createGoogleAuthSession() async {
  var googleAuthIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (googleAuthIdToken == null) {
    return createSession();
  }

  return createSessionUsingSocialProvider(
    CubeProvider.FIREBASE_EMAIL,
    DefaultFirebaseOptions.currentPlatform.projectId,
    googleAuthIdToken,
  ).then((_) {
    return CubeSessionManager.instance.activeSession!;
  });
}
