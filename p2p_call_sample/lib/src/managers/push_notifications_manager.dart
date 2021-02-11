import 'dart:io';

import 'package:device_id/device_id.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/consts.dart';
import '../utils/pref_util.dart';

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
      log('[onMessage] message: $remoteMessage', TAG);
      Map<String, dynamic> data = remoteMessage.data;

      ConnectycubeFlutterCallKit.showCallNotification(
        sessionId: data['session_id'],
        callType: int.parse(data['call_type']),
        callerId: int.parse(data['caller_id']),
        callerName: data['caller_name'],
      );
    });

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

    // TODO test after fix https://github.com/FirebaseExtended/flutterfire/issues/4898
    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpenedApp] remoteMessage: $remoteMessage', TAG);
    });
  }

  _initIosVoIP() async {
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

    bool isProduction = bool.fromEnvironment('dart.vm.product');

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.environment = CubeEnvironment.DEVELOPMENT; // TODO for sample we use DEVELOPMENT environment
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

processCallNotification(RemoteMessage message) async {
  log('[processCallNotification] message: ${message.data}',
      PushNotificationsManager.TAG);

  Map<String, dynamic> data = message.data;
  String signalType = data[PARAM_SIGNAL_TYPE];

  if (signalType == SIGNAL_TYPE_START_CALL) {
    ConnectycubeFlutterCallKit.showCallNotification(
      sessionId: data[PARAM_SESSION_ID],
      callType: int.parse(data[PARAM_CALL_TYPE]),
      callerId: int.parse(data[PARAM_CALLER_ID]),
      callerName: data[PARAM_CALLER_NAME],
    );
  } else if (signalType == SIGNAL_TYPE_END_CALL) {
    ConnectycubeFlutterCallKit.reportCallEnded(
        sessionId: data[PARAM_SESSION_ID]);
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('[onBackgroundMessage] message.data: ${message.data}',
      PushNotificationsManager.TAG);
  processCallNotification(message);
  return Future.value();
}
