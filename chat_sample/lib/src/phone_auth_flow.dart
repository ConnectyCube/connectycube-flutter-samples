import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/consts.dart';
import 'utils/pref_util.dart';
import 'utils/route_utils.dart';

class VerifyPhoneNumber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Navigation.verifyPhoneNavigation,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          builder: (context) => PhoneInputScreen(
            actions: [
              SMSCodeRequestedAction((ctx1, action, flowKey, phoneNumber) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx2) => SMSCodeInputScreen(
                      flowKey: flowKey,
                      actions: [
                        AuthStateChangeAction<SignedIn>((ctx3, state) {
                          log('[AuthStateChangeAction] SignedIn');
                          state.user?.getIdToken().then((idToken) {
                            SharedPrefs.instance.saveLoginType(LoginType.phone);
                            Navigator.of(ctx3, rootNavigator: true)
                                .pushNamedAndRemoveUntil(
                                    'login', (route) => false);
                          });
                        }),
                        AuthStateChangeAction<CredentialLinked>((ctx3, state) {
                          log('[AuthStateChangeAction] CredentialLinked');
                          state.user.getIdToken().then((idToken) {
                            SharedPrefs.instance.saveLoginType(LoginType.phone);
                            Navigator.of(ctx3, rootNavigator: true)
                                .pushNamedAndRemoveUntil(
                                    'login', (route) => false);
                          });
                        }),
                        AuthStateChangeAction<Uninitialized>((ctx3, state) {
                          log('[AuthStateChangeAction] Uninitialized');
                        }),
                        AuthStateChangeAction<CredentialReceived>(
                            (ctx3, state) {
                          log('[AuthStateChangeAction] CredentialReceived');
                        }),
                        AuthStateChangeAction<AuthFailed>((ctx3, state) {
                          log('[AuthStateChangeAction] AuthFailed');
                        }),
                        AuthStateChangeAction<UserCreated>((ctx3, state) {
                          log('[AuthStateChangeAction] UserCreated');
                          state.credential.user?.getIdToken().then((idToken) {
                            SharedPrefs.instance.saveLoginType(LoginType.phone);
                            Navigator.of(ctx3, rootNavigator: true)
                                .pushNamedAndRemoveUntil(
                                    'login', (route) => false);
                          });
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
