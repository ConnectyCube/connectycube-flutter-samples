import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/consts.dart';
import 'utils/pref_util.dart';
import 'utils/route_utils.dart';

const String phoneInputRouteName = 'PhoneInputScreen';
const String smsCodeInputRouteName = 'SMSCodeInputScreen';

class VerifyPhoneNumber extends StatelessWidget {
  const VerifyPhoneNumber({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [PhoneAuthRouteObserver(context)],
      key: Navigation.verifyPhoneNavigation,
      onGenerateRoute: (RouteSettings settings) {
        return PageRouteBuilder(
          reverseTransitionDuration:
              Duration(milliseconds: Platform.isIOS ? 1000 : 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          settings: const RouteSettings(name: phoneInputRouteName),
          pageBuilder: (context, animation, secondaryAnimation) =>
              PhoneInputScreen(
            actions: [
              SMSCodeRequestedAction((ctx1, action, flowKey, phoneNumber) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: smsCodeInputRouteName),
                    builder: (ctx2) => SMSCodeInputScreen(
                      flowKey: flowKey,
                      actions: [
                        AuthStateChangeAction<SignedIn>((ctx3, state) {
                          log('[AuthStateChangeAction] SignedIn');
                          state.user?.providerData.forEach((providerData) {
                            if (providerData.providerId ==
                                PhoneAuthProvider().providerId) {
                              state.user?.getIdToken().then((idToken) {
                                SharedPrefs.instance
                                    .saveLoginType(LoginType.phone);
                                Navigator.of(ctx3, rootNavigator: true)
                                    .pushNamedAndRemoveUntil(
                                        'login', (route) => false);
                              });
                            }
                          });
                        }),
                        AuthStateChangeAction<CredentialLinked>((ctx3, state) {
                          log('[AuthStateChangeAction] CredentialLinked');
                          for (var providerData in state.user.providerData) {
                            if (providerData.providerId ==
                                PhoneAuthProvider().providerId) {
                              state.user.getIdToken().then((idToken) {
                                SharedPrefs.instance
                                    .saveLoginType(LoginType.phone);
                                Navigator.of(ctx3, rootNavigator: true)
                                    .pushNamedAndRemoveUntil(
                                        'login', (route) => false);
                              });
                            }
                          }
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
                          state.credential.user?.providerData
                              .forEach((providerData) {
                            if (providerData.providerId ==
                                PhoneAuthProvider().providerId) {
                              state.credential.user
                                  ?.getIdToken()
                                  .then((idToken) {
                                SharedPrefs.instance
                                    .saveLoginType(LoginType.phone);
                                Navigator.of(ctx3, rootNavigator: true)
                                    .pushNamedAndRemoveUntil(
                                        'login', (route) => false);
                              });
                            }
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

class PhoneAuthRouteObserver extends RouteObserver {
  final BuildContext context;

  PhoneAuthRouteObserver(this.context);

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    if (route.settings.name == phoneInputRouteName) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
