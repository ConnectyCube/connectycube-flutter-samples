import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_apns/apns.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';

import 'call_screen.dart';
import 'utils/configs.dart' as utils;

class SelectOpponentsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Logged in as ${CubeChatConnection.instance.currentUser.fullName}',
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () => _logOut(context),
              icon: Icon(
                Icons.exit_to_app,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: BodyLayout(),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(false);
  }

  _logOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want logout current user"),
          actions: <Widget>[
            FlatButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            FlatButton(
              child: Text("OK"),
              onPressed: () {
                signOut().then(
                  (voidValue) {
                    CubeChatConnection.instance.destroy();
                    P2PClient.instance.destroy();
                    Navigator.pop(context); // cancel current Dialog
                    _navigateToLoginScreen(context);
                  },
                ).catchError(
                  (onError) {
                    P2PClient.instance.destroy();
                    Navigator.pop(context); // cancel current Dialog
                    _navigateToLoginScreen(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  _navigateToLoginScreen(BuildContext context) {
    Navigator.pop(context);
  }
}

class BodyLayout extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState();
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  Set<int> _selectedUsers;
  P2PClient _callClient;
  P2PSession _currentCall;
  bool _isSubscribed;
  FlutterVoipPushNotification _voipPush = FlutterVoipPushNotification();

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Text(
              "Select users to call:",
              style: TextStyle(fontSize: 22),
            ),
            Expanded(
              child: _getOpponentsList(context),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: FloatingActionButton(
                    heroTag: "VideoCall",
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.blue,
                    onPressed: () =>
                        _startCall(CallType.VIDEO_CALL, _selectedUsers),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: FloatingActionButton(
                    heroTag: "AudioCall",
                    child: Icon(
                      Icons.call,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.green,
                    onPressed: () =>
                        _startCall(CallType.AUDIO_CALL, _selectedUsers),
                  ),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _getOpponentsList(BuildContext context) {
    CubeUser currentUser = CubeChatConnection.instance.currentUser;
    final users =
        utils.users.where((user) => user.id != currentUser.id).toList();

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return Card(
          child: CheckboxListTile(
            title: Center(
              child: Text(
                users[index].fullName,
              ),
            ),
            value: _selectedUsers.contains(users[index].id),
            onChanged: ((checked) {
              setState(() {
                if (checked) {
                  _selectedUsers.add(users[index].id);
                } else {
                  _selectedUsers.remove(users[index].id);
                }
              });
            }),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _selectedUsers = {};
    _initCustomMediaConfigs();
    _initCalls();
    _isSubscribed = false;

    final connector = createPushConnector();

    connector.configure(
      onLaunch: onLaunch,
//      onResume: onResume,
//      onMessage: onMessage,
      onBackgroundMessage: onBackgroundMessage,
    );

    connector.requestNotificationPermissions();

//    if (connector.token.value != null) {
//      String token = connector.token.value;
//      log('Have token : $token');
//      _subscribeToPushes(token);
//    } else {
//      log('Add token listener');
//      connector.token.addListener(() {
//        String token = connector.token.value;
//        log('Token updated: $token');
//        _subscribeToPushes(token);
//      });
//    }
//    configure();
  }

  // Configures a voip push notification
  Future<void> configure() async {
    // request permission (required)
    await _voipPush.requestNotificationPermissions();

    // listen to voip device token changes
    _voipPush.onTokenRefresh.listen(onToken);

    // do configure voip push
    _voipPush.configure(onMessage: onMessage, onResume: onResume);
  }

  /// Called when the device token changes
  void onToken(String token) {
    log("onToken, token: $token");
    _subscribeToPushes(token);
  }

  /// Called to receive notification when app is in foreground
  ///
  /// [isLocal] is true if its a local notification or false otherwise (remote notification)
  /// [payload] the notification payload to be processed. use this to present a local notification
  Future<dynamic> onMessage(bool isLocal, Map<String, dynamic> payload) {
    // handle foreground notification
    log("received on foreground payload: $payload, isLocal=$isLocal");
    return null;
  }

  /// Called to receive notification when app is resuming from background
  ///
  /// [isLocal] is true if its a local notification or false otherwise (remote notification)
  /// [payload] the notification payload to be processed. use this to present a local notification
  Future<dynamic> onResume(bool isLocal, Map<String, dynamic> payload) {
    // handle background notification
    log("received on background payload: $payload, isLocal=$isLocal");
    showLocalNotification(payload);
    return null;
  }

  showLocalNotification(Map<String, dynamic> notification) {
    String alert = notification["aps"]["alert"];
    _voipPush.presentLocalNotification(LocalNotification(
      alertBody: "Hello $alert",
    ));
  }

  void _initCalls() {
    _callClient = P2PClient.instance;

    _callClient.init();

    _callClient.onReceiveNewSession = (callSession) {
      if (_currentCall != null &&
          _currentCall.sessionId != callSession.sessionId) {
        callSession.reject();
        return;
      }

      _showIncomingCallScreen(callSession);
    };

    _callClient.onSessionClosed = (callSession) {
      if (_currentCall != null &&
          _currentCall.sessionId == callSession.sessionId) {
        _currentCall = null;
      }
    };
  }

  void _startCall(int callType, Set<int> opponents) {
    if (opponents.isEmpty) return;

    P2PSession callSession = _callClient.createCallSession(callType, opponents);
    _currentCall = callSession;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(callSession, false),
      ),
    );
  }

  void _showIncomingCallScreen(P2PSession callSession) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(callSession),
      ),
    );
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    mediaConfig.minHeight = 720;
    mediaConfig.minWidth = 1280;
    mediaConfig.minFrameRate = 30;
  }

  void _subscribeToPushes(String token) {
//    if (!_isSubscribed) {
    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.environment = CubeEnvironment.DEVELOPMENT;

    String deviceId;

    if (Platform.isAndroid) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
      parameters.bundleIdentifier =
          "com.connectycube.flutter.p2p_call_sample"; // not required, a unique identifier for client's application. In iOS, this is the Bundle Identifier. In Android - package id
      deviceId =
          "2b6f0cc904d137be2e1730235f5664094b831186-android"; // some device identifier
    } else if (Platform.isIOS) {
      parameters.channel = NotificationsChannels.APNS_VOIP;
      parameters.platform = CubePlatform.IOS;
      parameters.bundleIdentifier =
          "com.connectycube.flutter.p2p-call-sample"; // not required, a unique identifier for client's application. In iOS, this is the Bundle Identifier. In Android - package id
      deviceId =
          "2b6f0cc904d137be2e1730235f5664094b831186-ios"; // some device identifier
    }

    parameters.udid = deviceId;
    parameters.pushToken = token;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('Successfully subscribed');
      setState(() {
        _isSubscribed = true;
      });
    }).catchError((error) {
      log('Subscription ERROR $error');
    });
//    }
  }
}

Future<dynamic> onBackgroundMessage(Map<String, dynamic> message) {
  log('onBackgroundMessage,message: $message');
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
  }

  // Or do other work.
  return Future.value();
}

Future<dynamic> onLaunch(Map<String, dynamic> data) {
  log('onLaunch, message: $data');
  return Future.value();
}

Future<dynamic> onResume(Map<String, dynamic> data) {
  log('onResume, message: $data');
  return Future.value();
}

Future<dynamic> onMessage(Map<String, dynamic> data) {
  log('onMessage, message: $data');
  return Future.value();
}
