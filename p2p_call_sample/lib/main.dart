import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src/login_screen.dart';
import 'src/managers/call_manager.dart';
import 'src/utils/configs.dart' as config;
import 'src/utils/pref_util.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: Builder(
        builder: (context) {
          CallManager.instance.init(context);

          return LoginScreen();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    initConnectycube();
  }
}

initConnectycube() {
  init(
    config.APP_ID,
    config.AUTH_KEY,
    config.AUTH_SECRET,
    onSessionRestore: () {
      return SharedPrefs.getUser().then((savedUser) {
        return createSession(savedUser);
      });
    },
  );
}
