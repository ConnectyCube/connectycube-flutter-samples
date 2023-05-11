import 'dart:async';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_io/io.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:uuid/uuid.dart';

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
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: DarwinInitializationSettings());
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

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
      onNotificationClicked?.call(jsonEncode(remoteMessage.data));
    });

    if (Platform.isIOS) {
      final connector = ApnsPushConnectorOnly();

      connector.configureApns(
        onLaunch: (message) async {
          log('[onLaunch] message.payload: ${message.payload}', TAG);
          var selectedDialogId = message.payload['data']['dialog_id'];
          if (selectedDialogId != null) {
            SharedPrefs.instance.init().then((prefs) {
              prefs.saveSelectedDialogId(selectedDialogId);
            });
          }
          // onNotificationClicked?.call(jsonEncode(message.payload['data']));
        },
        onResume: (message) async {
          log('[onResume] message.payload: ${message.payload}', TAG);
          onNotificationClicked?.call(jsonEncode(message.payload['data']));
        },
        onMessage: (message) async {
          log('[onResume] message.payload: ${message.payload}', TAG);
        },
      );
    }
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
    parameters.pushToken = token;

    bool isProduction = kIsWeb ? true : bool.fromEnvironment('dart.vm.product');
    parameters.environment =
        isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;

    if (Platform.isAndroid || kIsWeb) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
    } else if (Platform.isIOS || Platform.isMacOS) {
      parameters.channel = NotificationsChannels.APNS;
      parameters.platform = CubePlatform.IOS;
    }

    var deviceInfoPlugin = DeviceInfoPlugin();

    var deviceId;

    if (kIsWeb) {
      var webBrowserInfo = await deviceInfoPlugin.webBrowserInfo;
      deviceId = base64Encode(utf8.encode(webBrowserInfo.userAgent ?? ''));
    } else if (Platform.isAndroid) {
      var androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor;
    } else if (Platform.isMacOS) {
      var macOsInfo = await deviceInfoPlugin.macOsInfo;
      deviceId = macOsInfo.computerName;
    }

    parameters.udid = deviceId ?? Uuid().v4;

    var packageInfo = await PackageInfo.fromPlatform();
    parameters.bundleIdentifier = packageInfo.packageName;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.TAG);
      sharedPrefs.saveSubscriptionToken(token!);
      cubeSubscription.forEach((subscription) {
        if (subscription.clientIdentificationSequence == token) {
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
    onNotificationClicked?.call(payload);
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
  log('[onBackgroundMessage] message: ${message.data}',
      PushNotificationsManager.TAG);
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

      Map<String, dynamic> payloadObject = jsonDecode(payload);
      String? dialogId = payloadObject['dialog_id'];

      log("getNotificationAppLaunchDetails, dialog_id: $dialogId",
          PushNotificationsManager.TAG);

      getDialogs({'id': dialogId}).then((dialogs) {
        if (dialogs?.items != null && dialogs!.items.isNotEmpty) {
          CubeDialog dialog = dialogs.items.first;

          Navigator.pushNamed(context, 'chat_dialog',
              arguments: {USER_ARG_NAME: user, DIALOG_ARG_NAME: dialog});
        }
      });
    });
  } else {
    return Future.value();
  }
}
