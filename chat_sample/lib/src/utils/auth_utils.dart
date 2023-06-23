import 'package:firebase_auth/firebase_auth.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../../firebase_options.dart';

Future<CubeSession> createPhoneAuthSession() async {
  var phoneAuthIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (phoneAuthIdToken == null) {
    return createSession();
  }

  return createSession().then((cubeSession) {
    return signInUsingFirebase(
      DefaultFirebaseOptions.currentPlatform.projectId,
      phoneAuthIdToken,
    ).then((_) {
      return CubeSessionManager.instance.activeSession!;
    });
  });
}
