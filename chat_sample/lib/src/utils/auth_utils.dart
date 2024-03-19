import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../../firebase_options.dart';

Future<CubeSession> createPhoneAuthSession() async {
  var phoneAuthIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (phoneAuthIdToken == null) {
    return createSession();
  }

  return createSession().then((cubeSession) {
    return signInUsingFirebasePhone(
      DefaultFirebaseOptions.currentPlatform.projectId,
      phoneAuthIdToken,
    ).then((_) {
      return CubeSessionManager.instance.activeSession!;
    });
  });
}

Future<CubeSession> createFacebookAuthSession() async {
  final AccessToken? accessToken = await FacebookAuth.instance.accessToken;
  if (accessToken == null) {
    return createSession();
  }

  return createSession().then((cubeSession) {
    return signInUsingSocialProvider(
      CubeProvider.FACEBOOK,
      accessToken.token,
    ).then((cubeUser) {
      return CubeSessionManager.instance.activeSession!;
    });
  });
}

Future<CubeSession> createGoogleAuthSession() async {
  var googleAuthIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (googleAuthIdToken == null) {
    return createSession();
  }

  return createSession().then((cubeSession) {
    return signInUsingFirebaseEmail(
      DefaultFirebaseOptions.currentPlatform.projectId,
      googleAuthIdToken,
    ).then((_) {
      return CubeSessionManager.instance.activeSession!;
    });
  });
}
