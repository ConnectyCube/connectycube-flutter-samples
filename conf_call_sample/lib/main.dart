import 'package:conf_call_sample/src/utils/call_manager.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src/utils/configs.dart' as config;
import 'src/login_screen.dart';
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
    initCallManager(context);

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

    initConnectycube();
  }

  void initCallManager(BuildContext context) {
    SharedPrefs.getUser().then((savedUser) {
      if(savedUser != null){
        CallManager.instance.init(context);
      }
    });
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

  // setEndpoints('https://', '');

  ConferenceConfig.instance.url = config.SERVER_ENDPOINT;
}

initConnectycubeContextLess() {
  CubeSettings.instance.applicationId = config.APP_ID;
  CubeSettings.instance.authorizationKey = config.AUTH_KEY;
  CubeSettings.instance.authorizationSecret = config.AUTH_SECRET;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPrefs.getUser().then((savedUser) {
      return createSession(savedUser);
    });
  };
}
