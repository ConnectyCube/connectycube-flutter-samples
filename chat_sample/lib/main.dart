import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:universal_io/io.dart';

import 'firebase_options.dart';
import 'src/chat_details_screen.dart';
import 'src/chat_dialog_screen.dart';
import 'src/chat_dialog_resizable_screen.dart';
import 'src/login_screen.dart';
import 'src/managers/push_notifications_manager.dart';
import 'src/select_dialog_screen.dart';
import 'src/settings_screen.dart';
import 'src/utils/auth_utils.dart';
import 'src/utils/configs.dart' as config;
import 'src/utils/consts.dart';
import 'src/utils/platform_utils.dart' as platform_utils;
import 'src/utils/pref_util.dart';
import 'src/utils/route_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  log('[main]');

  if (kIsWeb || !(Platform.isLinux && Platform.isWindows)) {
    log('[main] init Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      await FacebookAuth.i.webAndDesktopInitialize(
        appId: '786550356345266',
        cookie: true,
        xfbml: true,
        version: 'v16.0',
      );
    }
  }

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late StreamSubscription<ConnectivityResult> connectivityStateSubscription;
  AppLifecycleState? appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.green,
      ),
      home: const LoginScreen(),
      navigatorKey: Navigation.mainNavigation,
      onGenerateRoute: (settings) {
        String? name = settings.name;
        Map<String, dynamic>? args =
            settings.arguments as Map<String, dynamic>?;

        MaterialPageRoute pageRout;

        switch (name) {
          case 'chat_dialog':
            pageRout = MaterialPageRoute(
                builder: (context) => platform_utils.isDesktop()
                    ? ChatDialogResizableScreen(
                        args![userArgName], args[dialogArgName])
                    : ChatDialogScreen(
                        args![userArgName], args[dialogArgName]));
            break;

          case 'chat_dialog_resizable':
            pageRout = MaterialPageRoute<bool>(
              builder: (context) => ChatDialogResizableScreen(
                  args![userArgName], args[dialogArgName]),
            );

            break;

          case 'chat_details':
            pageRout = MaterialPageRoute(
                builder: (context) =>
                    ChatDetailsScreen(args![userArgName], args[dialogArgName]));
            break;

          case 'select_dialog':
            pageRout = MaterialPageRoute<bool>(
                builder: (context) => platform_utils.isDesktop()
                    ? ChatDialogResizableScreen(
                        args![userArgName], args[dialogArgName])
                    : SelectDialogScreen(args![userArgName], null, null));

            break;

          case 'login':
            pageRout =
                MaterialPageRoute(builder: (context) => const LoginScreen());
            break;

          case 'settings':
            pageRout = MaterialPageRoute(
                builder: (context) => SettingsScreen(args![userArgName]));
            break;

          default:
            pageRout =
                MaterialPageRoute(builder: (context) => const LoginScreen());

            break;
        }

        PushNotificationsManager.instance.onNotificationClicked = (payload) {
          return onNotificationSelected(payload, pageRout.subtreeContext);
        };

        return pageRout;
      },
    );
  }

  @override
  void initState() {
    super.initState();

    init(config.appId, config.authKey, config.authSecret,
        onSessionRestore: () async {
      SharedPrefs sharedPrefs = await SharedPrefs.instance.init();

      var loginType = sharedPrefs.getLoginType();

      switch (loginType) {
        case LoginType.phone:
          return createPhoneAuthSession();
        case LoginType.facebook:
          return createFacebookAuthSession();
        case LoginType.google:
          return createGoogleAuthSession();

        case LoginType.login:
        case LoginType.email:
          return createSession(sharedPrefs.getUser());

        default:
          return createSession(sharedPrefs.getUser());
      }
    });

    setEndpoints(config.apiEndpoint, config.chatEndpoint);

    connectivityStateSubscription =
        Connectivity().onConnectivityChanged.listen((connectivityType) {
      if (AppLifecycleState.resumed != appState) return;

      if (connectivityType != ConnectivityResult.none) {
        log("chatConnectionState = ${CubeChatConnection.instance.chatConnectionState}");
        bool isChatDisconnected =
            CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.Closed ||
                CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.ForceClosed;

        if (isChatDisconnected &&
            CubeChatConnection.instance.currentUser != null) {
          CubeChatConnection.instance.relogin();
        }
      }
    });

    appState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    connectivityStateSubscription.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("Current app state: $state");
    appState = state;

    if (AppLifecycleState.paused == state) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        CubeChatConnection.instance.markInactive();
      }
    } else if (AppLifecycleState.resumed == state) {
      // just for an example user was saved in the local storage
      SharedPrefs.instance.init().then((sharedPrefs) async {
        CubeUser? user = sharedPrefs.getUser();

        if (user != null) {
          if (!CubeChatConnection.instance.isAuthenticated()) {
            var loginType = sharedPrefs.getLoginType();
            if (loginType != LoginType.login && loginType != LoginType.email) {
              if (CubeSessionManager.instance.isActiveSessionValid()) {
                user.password =
                    CubeSessionManager.instance.activeSession?.token;
              } else if (LoginType.phone == loginType) {
                var phoneAuthSession = await createPhoneAuthSession();
                user.password = phoneAuthSession.token;
              } else if (LoginType.facebook == loginType) {
                var facebookAuthSession = await createFacebookAuthSession();
                user.password = facebookAuthSession.token;
              }
            }
            CubeChatConnection.instance.login(user);
          } else {
            CubeChatConnection.instance.markActive();
          }
        }
      });
    }
  }
}
