import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform_device_id/platform_device_id.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/consts.dart';
import 'utils/pref_util.dart';

class PushNotificationsManager {
  static const TAG = "PushNotificationsManager";

  static final PushNotificationsManager _instance =
      PushNotificationsManager._internal();

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  PushNotificationsManager._internal() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  BuildContext? applicationContext;

  static PushNotificationsManager get instance => _instance;

  Future<dynamic> Function(String? payload)? onNotificationClicked;

  init() async {
    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    await firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher_foreground');
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: MacOSInitializationSettings());
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    String? token;
    if (Platform.isAndroid || kIsWeb) {
      firebaseMessaging.getToken().then((token) {
        log('[getToken] token: $token', TAG);
        subscribe(token);
      }).catchError((onError) {
        log('[getToken] onError: $onError', TAG);
      });
    } else if (Platform.isIOS || Platform.isMacOS) {
      token = await firebaseMessaging.getAPNSToken();
      log('[getAPNSToken] token: $token', TAG);
    }

    if (!isEmpty(token)) {
      subscribe(token);
    }

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      subscribe(newToken);
    });

    FirebaseMessaging.onMessage.listen((remoteMessage) {
      log('[onMessage] message: ${remoteMessage.data}', TAG);
      showNotification(remoteMessage);
    });

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

    // TODO test after fix https://github.com/FirebaseExtended/flutterfire/issues/4898
    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpenedApp] remoteMessage: $remoteMessage', TAG);
      if (onNotificationClicked != null) {
        onNotificationClicked!.call(jsonEncode(remoteMessage.data));
      }
    });
  }

  subscribe(String? token) async {
    log('[subscribe] token: $token', PushNotificationsManager.TAG);

    SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
    if (sharedPrefs.getSubscriptionToken() == token) {
      log('[subscribe] skip subscription for same token',
          PushNotificationsManager.TAG);
      return;
    }

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.environment = CubeEnvironment.DEVELOPMENT; // doesn't matter, server will send to both environments

    if (Platform.isAndroid || kIsWeb) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
      parameters.bundleIdentifier = "com.connectycube.flutter.chat_sample";
    } else if (Platform.isIOS || Platform.isMacOS) {
      parameters.channel = NotificationsChannels.APNS;
      parameters.platform = CubePlatform.IOS;
      parameters.bundleIdentifier = Platform.isIOS
          ? "com.connectycube.flutter.chatSample.app"
          : "com.connectycube.flutter.chatSample.macOS";
    }

    String? deviceId = await PlatformDeviceId.getDeviceId;
    parameters.udid = deviceId;
    parameters.pushToken = token;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.TAG);
      sharedPrefs.saveSubscriptionToken(token!);
      cubeSubscription.forEach((subscription) {
        if (subscription.device!.clientIdentificationSequence == token) {
          sharedPrefs.saveSubscriptionId(subscription.id!);
        }
      });
    }).catchError((error) {
      log('[subscribe] subscription ERROR: $error',
          PushNotificationsManager.TAG);
    });
  }

  unsubscribe() {
    SharedPrefs.instance.init().then((sharedPrefs) {
      int subscriptionId = sharedPrefs.getSubscriptionId();
      if (subscriptionId != 0) {
        deleteSubscription(subscriptionId).then((voidResult) {
          FirebaseMessaging.instance.deleteToken();
          sharedPrefs.saveSubscriptionId(0);
        });
      }
    }).catchError((onError) {
      log('[unsubscribe] ERROR: $onError', PushNotificationsManager.TAG);
    });
  }

  Future<dynamic> onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    log('[onDidReceiveLocalNotification] id: $id , title: $title, body: $body, payload: $payload',
        PushNotificationsManager.TAG);
    return Future.value();
  }

  Future<dynamic> onSelectNotification(String? payload) {
    log('[onSelectNotification] payload: $payload',
        PushNotificationsManager.TAG);
    if (onNotificationClicked != null) {
      onNotificationClicked!.call(payload);
    }
    return Future.value();
  }
}

showNotification(RemoteMessage message) async {
  log('[showNotification] message: ${message.data}',
      PushNotificationsManager.TAG);
  Map<String, dynamic> data = message.data;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'messages_channel_id',
    'Chat messages',
    channelDescription: 'Chat messages will be received here',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    color: Colors.green,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  FlutterLocalNotificationsPlugin().show(
    6543,
    "Chat sample",
    data['message'].toString(),
    platformChannelSpecifics,
    payload: jsonEncode(data),
  );
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  log('[onBackgroundMessage] message: ${message.data}', PushNotificationsManager.TAG);
  showNotification(message);
  return Future.value();
}

Future<dynamic> onNotificationSelected(String? payload, BuildContext? context) {
  log('[onSelectNotification] payload: $payload', PushNotificationsManager.TAG);

  if (context == null) return Future.value();

  log('[onSelectNotification] context != null', PushNotificationsManager.TAG);

  if (payload != null) {
    return SharedPrefs.instance.init().then((sharedPrefs) {
      CubeUser? user = sharedPrefs.getUser();

      if (user != null && !CubeChatConnection.instance.isAuthenticated()) {
        Map<String, dynamic> payloadObject = jsonDecode(payload);
        String? dialogId = payloadObject['dialog_id'];

        log("getNotificationAppLaunchDetails, dialog_id: $dialogId",
            PushNotificationsManager.TAG);

        getDialogs({'id': dialogId}).then((dialogs) {
          if (dialogs?.items != null && dialogs!.items.isNotEmpty) {
            CubeDialog dialog = dialogs.items.first;

            Navigator.pushReplacementNamed(context, 'chat_dialog',
                arguments: {USER_ARG_NAME: user, DIALOG_ARG_NAME: dialog});
          }
        });
      }
    });
  } else {
    return Future.value();
  }
}
