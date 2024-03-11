import 'dart:math';

import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'src/managers/call_manager.dart';
import 'src/screens/conversation_call_screen.dart';
import 'src/screens/incoming_call_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/select_opponents_screen.dart';
import 'src/utils/configs.dart' as config;
import 'src/utils/consts.dart';
import 'src/utils/platform_utils.dart';
import 'src/utils/pref_util.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configurePlatform();
  runApp(App());
}

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

          var meetingId = params[ARG_MEETING_ID];

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
          case LOGIN_SCREEN:
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());
            break;

          case CONVERSATION_SCREEN:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => ConversationCallScreen(
                        args[ARG_USER],
                        args[ARG_CALL_SESSION],
                        args[ARG_MEETING_ID],
                        args[ARG_OPPONENTS],
                        args[ARG_IS_INCOMING],
                        args[ARG_CALL_NAME],
                        initialLocalMediaStream:
                            args[ARG_INITIAL_LOCAL_MEDIA_STREAM],
                        isFrontCameraUsed: args[ARG_IS_FRONT_CAMERA_USED],
                        isSharedCall: args[ARG_IS_SHARED_CALL],
                      ));
            }
            break;

          case SELECT_OPPONENTS_SCREEN:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => SelectOpponentsScreen(args[ARG_USER]));
            }

            break;

          case INCOMING_CALL_SCREEN:
            if (args != null) {
              pageRout = MaterialPageRoute(
                  builder: (context) => IncomingCallScreen(
                      args[ARG_USER],
                      args[ARG_CALL_ID],
                      args[ARG_MEETING_ID],
                      args[ARG_INITIATOR_ID],
                      args[ARG_OPPONENTS],
                      args[ARG_CALL_TYPE],
                      args[ARG_CALL_NAME]));
            }

            break;

          default:
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());

            break;
        }

        return pageRout ??
            MaterialPageRoute(builder: (context) => LoginScreen());
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

    if (currentUser == null) {
      currentUser = await createSession(CubeUser(
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
    }

    return ConferenceClient.instance
        .createCallSession(
      currentUser!.id!,
      callType: CallType.VIDEO_CALL,
    )
        .then((confSession) {
      CallManager.instance.init(context);
      CallManager.instance.currentCallState = InternalCallState.ACCEPTED;
      CallManager.instance.setActiveCall('', meetingId, -1, []);
      CallManager.instance.sendAcceptMessage('', meetingId, -1);

      return ConversationCallScreen(
        currentUser!,
        confSession,
        meetingId,
        [],
        true,
        'Shared conference',
        isSharedCall: true,
      );
    });
  }
}

initConnectycube() {
  init(
    config.APP_ID,
    config.AUTH_KEY,
    config.AUTH_SECRET,
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

  setEndpoints(config.API_ENDPOINT, config.CHAT_ENDPOINT);

  ConferenceConfig.instance.url = config.CONF_SERVER_ENDPOINT;
}

initConnectycubeContextLess() async {
  CubeSettings.instance.applicationId = config.APP_ID;
  CubeSettings.instance.authorizationKey = config.AUTH_KEY;
  CubeSettings.instance.authorizationSecret = config.AUTH_SECRET;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPrefs.getUser().then((savedUser) {
      return createSession(savedUser);
    });
  };

  CubeSettings.instance.apiEndpoint = config.API_ENDPOINT;
  CubeSettings.instance.chatEndpoint = config.CHAT_ENDPOINT;

  ConferenceConfig.instance.url = config.CONF_SERVER_ENDPOINT;
}
