import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src/config.dart' as config;
import 'src/login_screen.dart';
import 'src/utils/pref_util.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: Builder(
        builder: (context) {
          return const LoginScreen();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    ConnectycubeFlutterCallKit.instance.init();

    initConnectycube();
  }
}

initConnectycube() {
  init(
    config.appId,
    config.authKey,
    config.authSecret,
    onSessionRestore: () {
      return SharedPrefs.getUser().then((savedUser) {
        return createSession(savedUser);
      });
    },
  );
  setEndpoints(config.apiEndpoint, config.chatEndpoint);
}

initConnectycubeContextLess() {
  CubeSettings.instance.applicationId = config.appId;
  CubeSettings.instance.authorizationKey = config.authKey;
  CubeSettings.instance.authorizationSecret = config.authSecret;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPrefs.getUser().then((savedUser) {
      return createSession(savedUser);
    });
  };

  setEndpoints(config.apiEndpoint, config.chatEndpoint);
}
