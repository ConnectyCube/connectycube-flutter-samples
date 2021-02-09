import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:p2p_call_sample/src/utils/pref_util.dart';

import 'src//utils/configs.dart' as config;
import 'src/login_screen.dart';

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
      home: LoginScreen(),
    );
  }

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();

    init(
      config.APP_ID,
      config.AUTH_KEY,
      config.AUTH_SECRET,
      onSessionRestore: () {
        return SharedPrefs.instance.init().then((preferences) {
          return createSession(preferences.getUser());
        });
      },
    );
  }
}
