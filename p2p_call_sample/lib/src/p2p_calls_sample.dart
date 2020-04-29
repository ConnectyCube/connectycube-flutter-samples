import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'login_screen.dart';
import 'utils/configs.dart' as config;

void main() => runApp(_App());

class _App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<_App> {
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
    init(
      config.APP_ID,
      config.AUTH_KEY,
      config.AUTH_SECRET,
    );
  }
}
