import 'dart:math';

import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src/config.dart' as config;
import 'src/managers/call_manager.dart';
import 'src/screens/conversation_call_screen.dart';
import 'src/screens/incoming_call_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/select_opponents_screen.dart';
import 'src/utils/consts.dart';
import 'src/utils/platform_utils.dart';
import 'src/utils/pref_util.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configurePlatform();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LoginScreen(),
      onGenerateRoute: (settings) {
        String? routeName = settings.name;
        String? name = routeName?.split('?').firstOrNull;
        Map<String, dynamic>? args =
            settings.arguments as Map<String, dynamic>?;

        MaterialPageRoute? pageRout;

        name = name?.replaceFirst('/', '');

        var uri = Uri.tryParse('$routeName');
        if (uri != null) {
          var params = uri.queryParameters;

          var meetingId = params[argMeetingId];

          if (meetingId != null) {
            return MaterialPageRoute(builder: (context) {
              return FutureBuilder(
                  future: prepareConversationScreen(meetingId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Container();
                    } else {
                      return snapshot.data!;
                    }
                  });
            });
          }
        }

        switch (name) {
          case loginScreen:
            pageRout =
                MaterialPageRoute(builder: (context) => const LoginScreen());
            break;

          case conversationScreen:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => ConversationCallScreen(
                        args[argUser],
                        args[argCallSession],
                        args[argMeetingId],
                        args[argOpponents],
                        args[argIsIncoming],
                        args[argCallName],
                        initialLocalMediaStream:
                            args[argInitialLocalMediaStream],
                        isFrontCameraUsed: args[argIsFrontCameraUsed],
                        isSharedCall: args[argIsSharedCall],
                      ));
            }
            break;

          case selectOpponentsScreen:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => SelectOpponentsScreen(args[argUser]));
            }

            break;

          case incomingCallScreen:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => IncomingCallScreen(
                      args[argUser],
                      args[argCallId],
                      args[argMeetingId],
                      args[argInitiatorId],
                      args[argOpponents],
                      args[argCallType],
                      args[argCallName]));
            }

            break;

          default:
            pageRout =
                MaterialPageRoute(builder: (context) => const LoginScreen());

            break;
        }

        return pageRout ??
            MaterialPageRoute(builder: (context) => const LoginScreen());
      },
    );
  }

  @override
  void initState() {
    super.initState();

    initConnectycube();
  }

  void initCallManager(BuildContext context) {
    SharedPrefs.getUser().then((savedUser) {
      if (savedUser != null) {
        CallManager.instance.init(context);
      }
    });
  }

  Future<Widget> prepareConversationScreen(String meetingId) async {
    var currentUser = await SharedPrefs.getUser();

    currentUser ??= await createSession(CubeUser(
            isGuest: true, fullName: 'Guest ${Random().nextInt(1024)}'))
        .then((session) {
      CubeChatConnection.instance
          .login(CubeUser(id: session.user!.id!, password: session.token))
          .then((value) {
        log('[prepareConversationScreen] CHAT login SUCCESS', 'App');
        SharedPrefs.saveNewUser(session.user!..password = session.token);
        SharedPrefs.saveSession(session);
      });

      return session.user;
    });

    return ConferenceClient.instance
        .createCallSession(
      currentUser!.id!,
      callType: CallType.VIDEO_CALL,
    )
        .then((confSession) {
      CallManager.instance.init(context);
      CallManager.instance.currentCallState = InternalCallState.accepted;
      CallManager.instance.setActiveCall('', meetingId, -1, []);
      CallManager.instance.sendAcceptMessage('', meetingId, -1);

      return ConversationCallScreen(
        currentUser!,
        confSession,
        meetingId,
        const [],
        true,
        'Shared conference',
        isSharedCall: true,
      );
    });
  }
}

initConnectycube() {
  init(
    config.appId,
    config.authKey,
    '',
    onSessionRestore: () {
      return SharedPrefs.getUser().then((savedUser) async {
        if (savedUser?.isGuest ?? false) {
          return SharedPrefs.getSession().then((savedSession) {
            if (savedSession != null) {
              CubeSessionManager.instance.activeSession = savedSession;
              return savedSession;
            } else {
              return createSession(savedUser);
            }
          });
        }
        return createSession(savedUser);
      });
    },
  );

  setEndpoints(config.apiEndpoint, config.chatEndpoint);

  ConferenceConfig.instance.url = config.confServerEndpoint;
}

initConnectycubeContextLess() async {
  CubeSettings.instance.applicationId = config.appId;
  CubeSettings.instance.authorizationKey = config.authKey;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPrefs.getUser().then((savedUser) {
      return createSession(savedUser);
    });
  };

  CubeSettings.instance.apiEndpoint = config.apiEndpoint;
  CubeSettings.instance.chatEndpoint = config.chatEndpoint;

  ConferenceConfig.instance.url = config.confServerEndpoint;
}
