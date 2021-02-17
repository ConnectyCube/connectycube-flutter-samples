import 'dart:io';

import 'package:device_id/device_id.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/consts.dart';
import '../utils/pref_util.dart';
import '../utils/configs.dart' as config;

class PushNotificationsManager {
  static const TAG = "PushNotificationsManager";

  static final PushNotificationsManager _instance =
      PushNotificationsManager._internal();

  PushNotificationsManager._internal() {
    Firebase.initializeApp();
  }

  BuildContext applicationContext;

  static PushNotificationsManager get instance => _instance;

  FlutterVoipPushNotification _voipPush = FlutterVoipPushNotification();

  init() async {
    if (Platform.isAndroid) {
      _initFcm();
    } else if (Platform.isIOS) {
      _initIosVoIP();
    }

    FirebaseMessaging.onMessage.listen((remoteMessage) async {
      processCallNotification(remoteMessage.data);
    });

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

    // TODO test after fix https://github.com/FirebaseExtended/flutterfire/issues/4898
    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpenedApp] remoteMessage: $remoteMessage', TAG);
    });
  }

  _initIosVoIP() async {
    await _voipPush.requestNotificationPermissions();
    _voipPush.configure(onMessage: onMessage, onResume: onResume);

    _voipPush.onTokenRefresh.listen((token) {
      log('[onTokenRefresh] VoIP token: $token', TAG);
      subscribe(token);
    });
  }

  _initFcm() async {
    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    await firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true);

    firebaseMessaging.getToken().then((token) {
      log('[getToken] FCM token: $token', TAG);
      subscribe(token);
    }).catchError((onError) {
      log('[getToken] onError: $onError', TAG);
    });

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      log('[onTokenRefresh] FCM token: $newToken', TAG);
      subscribe(newToken);
    });
  }

  subscribe(String token) async {
    log('[subscribe] token: $token', PushNotificationsManager.TAG);

    SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
    if (sharedPrefs.getSubscriptionToken() == token) {
      log('[subscribe] skip subscription for same token',
          PushNotificationsManager.TAG);
      return;
    }


    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.environment = CubeEnvironment
        .DEVELOPMENT; // TODO for sample we use DEVELOPMENT environment
    // bool isProduction = bool.fromEnvironment('dart.vm.product');
    // parameters.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;

    if (Platform.isAndroid) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
      parameters.bundleIdentifier = "com.connectycube.flutter.p2p_call_sample";
    } else if (Platform.isIOS) {
      parameters.channel = NotificationsChannels.APNS_VOIP;
      parameters.platform = CubePlatform.IOS;
      parameters.bundleIdentifier = "com.connectycube.flutter.p2p-call-sample";
    }

    String deviceId = await DeviceId.getID;
    parameters.udid = deviceId;
    parameters.pushToken = token;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.TAG);
      sharedPrefs.saveSubscriptionToken(token);
      cubeSubscription.forEach((subscription) {
        if (subscription.device.clientIdentificationSequence == token) {
          sharedPrefs.saveSubscriptionId(subscription.id);
        }
      });
    }).catchError((error) {
      log('[subscribe] subscription ERROR: $error',
          PushNotificationsManager.TAG);
    });
  }

  Future<void> unsubscribe() {
    return SharedPrefs.instance.init().then((sharedPrefs) async {
      int subscriptionId = sharedPrefs.getSubscriptionId();
      if (subscriptionId != 0) {
        return deleteSubscription(subscriptionId).then((voidResult) {
          FirebaseMessaging.instance.deleteToken();
          sharedPrefs.saveSubscriptionId(0);
        });
      } else {
        return Future.value();
      }
    }).catchError((onError) {
      log('[unsubscribe] ERROR: $onError', PushNotificationsManager.TAG);
    });
  }
}

Future<dynamic> onMessage(bool isLocal, Map<String, dynamic> payload) {
  log("[onMessage] received on foreground payload: $payload, isLocal=$isLocal",
      PushNotificationsManager.TAG);

  processCallNotification(payload);

  return null;
}

Future<dynamic> onResume(bool isLocal, Map<String, dynamic> payload) {
  log("[onResume] received on background payload: $payload, isLocal=$isLocal",
      PushNotificationsManager.TAG);

  return null;
}

processCallNotification(Map<String, dynamic> data) async {
  log('[processCallNotification] message: $data', PushNotificationsManager.TAG);

  String signalType = data[PARAM_SIGNAL_TYPE];
  String sessionId = data[PARAM_SESSION_ID];
  Set<int> opponentsIds = (data[PARAM_CALL_OPPONENTS] as String)
      .split(',')
      .map((e) => int.parse(e))
      .toSet();

  if (signalType == SIGNAL_TYPE_START_CALL) {
    ConnectycubeFlutterCallKit.showCallNotification(
        sessionId: sessionId,
        callType: int.parse(data[PARAM_CALL_TYPE]),
        callerId: int.parse(data[PARAM_CALLER_ID]),
        callerName: data[PARAM_CALLER_NAME],
        opponentsIds: opponentsIds);
  } else if (signalType == SIGNAL_TYPE_END_CALL) {
    ConnectycubeFlutterCallKit.reportCallEnded(
        sessionId: data[PARAM_SESSION_ID]);
  } else if (signalType == SIGNAL_TYPE_REJECT_CALL) {
    if (opponentsIds.length == 1) {
      CallManager.instance.hungUp();
    }
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  ConnectycubeFlutterCallKit.onCallAcceptedWhenTerminated = (
    sessionId,
    callType,
    callerId,
    callerName,
    opponentsIds,
  ) {
    return sendPushAboutRejectFromKilledState({
      PARAM_CALL_TYPE: callType,
      PARAM_SESSION_ID: sessionId,
      PARAM_CALLER_ID: callerId,
      PARAM_CALLER_NAME: callerName,
      PARAM_CALL_OPPONENTS: opponentsIds.join(','),
    }, callerId);
  };
  ConnectycubeFlutterCallKit.initMessagesHandler();

  processCallNotification(message.data);

  return Future.value();
}

Future<void> sendPushAboutRejectFromKilledState(
  Map<String, dynamic> parameters,
  int callerId,
) {
  CubeSettings.instance.applicationId = config.APP_ID;
  CubeSettings.instance.authorizationKey = config.AUTH_KEY;
  CubeSettings.instance.authorizationSecret = config.AUTH_SECRET;
  CubeSettings.instance.accountKey = config.ACCOUNT_ID;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPrefs.instance.init().then((preferences) {
      return createSession(preferences.getUser());
    });
  };

  CreateEventParams params = CreateEventParams();
  params.parameters = parameters;
  params.parameters['message'] = "Reject call";
  params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_REJECT_CALL;
  params.parameters[PARAM_IOS_VOIP] = 1;

  params.notificationType = NotificationType.PUSH;
  params.environment = CubeEnvironment
      .DEVELOPMENT; // TODO for sample we use DEVELOPMENT environment
  // bool isProduction = bool.fromEnvironment('dart.vm.product');
  // params.environment =
  //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = [callerId];

  return createEvent(params.getEventForRequest());
}
