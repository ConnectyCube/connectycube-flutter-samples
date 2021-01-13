import 'dart:convert';

import 'package:chat_sample/src/chat_details_screen.dart';
import 'package:chat_sample/src/chat_dialog_screen.dart';
import 'package:chat_sample/src/select_dialog_screen.dart';
import 'package:chat_sample/src/settings_screen.dart';
import 'package:chat_sample/src/utils/consts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dart:developer' as dev_log;

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src//utils/configs.dart' as config;
import 'src/login_screen.dart';
import 'src/push_notifications_manager.dart';
import 'src/utils/pref_util.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: LoginScreen(),
      onGenerateRoute: (settings) {
        String name = settings.name;
        Map<String, dynamic> args = settings.arguments;

        MaterialPageRoute pageRout;
        bool userRequired = false;
        bool isPossibleRoutToChat = false;

        switch (name) {
          case 'chat_dialog':
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDialogScreen(
                    args[USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            isPossibleRoutToChat = true;
            break;
          case 'chat_details':
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                    args[USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            isPossibleRoutToChat = true;
            break;

          case 'select_dialog':
            pageRout = MaterialPageRoute<bool>(
                builder: (context) => SelectDialogScreen(args[USER_ARG_NAME]));

            isPossibleRoutToChat = true;
            break;

          case 'login':
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());
            break;

          case 'settings':
            pageRout = MaterialPageRoute(
                builder: (context) => SettingsScreen(args[USER_ARG_NAME]));
            isPossibleRoutToChat = true;
            break;

          default:
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());

            break;
        }

        if (isPossibleRoutToChat) {
          PushNotificationsManager.instance.onNotificationClicked = (payload) {
            return onSelectNotification(payload, pageRout.subtreeContext);
          };
        }

        return pageRout;
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Firebase.initializeApp();

    init(config.APP_ID, config.AUTH_KEY, config.AUTH_SECRET,
        onSessionRestore: () async {
      SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
      CubeUser user = sharedPrefs.getUser();

      return createSession(user);
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("Current app state: $state");

    if (AppLifecycleState.paused == state) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        CubeChatConnection.instance.logout();
      }
    } else if (AppLifecycleState.resumed == state) {
      SharedPrefs.instance.init().then((sharedPrefs) {
        CubeUser user = sharedPrefs.getUser();

        if (user != null && !CubeChatConnection.instance.isAuthenticated()) {
          CubeChatConnection.instance.login(user).then((cubeUser) {
            dev_log.log("Logged in to the chat",
                time: DateTime.now(), level: 900);
          });
        }
      });
    }
  }
}

Future<dynamic> onSelectNotification(String payload, BuildContext context) {
  dev_log.log('[onSelectNotification] payload: $payload');

  if (payload != null) {
    return SharedPrefs.instance.init().then((sharedPrefs) {
      CubeUser user = sharedPrefs.getUser();

      if (user != null && !CubeChatConnection.instance.isAuthenticated()) {
        Map<String, dynamic> payloadObject = jsonDecode(payload);
        String dialogId = payloadObject['dialog_id'];

        dev_log.log("getNotificationAppLaunchDetails, dialog_id: $dialogId");

        getDialogs({'id': dialogId}).then((dialogs) {
          if (dialogs?.items != null && dialogs.items.isNotEmpty ?? false) {
            CubeDialog dialog = dialogs.items.first;

            Navigator.pushNamed(context, 'chat_dialog',
                arguments: {USER_ARG_NAME: user, DIALOG_ARG_NAME: dialog});
          }
        });
      }
    });
  } else {
    return Future.value();
  }
}
