import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/consts.dart';
import '../utils/platform_utils.dart';
import '../utils/pref_util.dart';

class PushNotificationsManager {
  static const tag = "PushNotificationsManager";

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
    log('[init]', tag);
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
            macOS: const DarwinInitializationSettings());
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        log('[onDidReceiveNotificationResponse] payload: ${notificationResponse.payload}',
            tag);
        var data = notificationResponse.payload;
        if (data != null) {
          if (onNotificationClicked != null) {
            onNotificationClicked?.call(data);
          } else {
            String? dialogId = jsonDecode(data)['dialog_id'];
            SharedPrefs.instance.saveSelectedDialogId(dialogId ?? '');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    String? token;
    if (Platform.isAndroid || kIsWeb || Platform.isIOS || Platform.isMacOS) {
      firebaseMessaging.getToken().then((token) {
        log('[getToken] token: $token', tag);
        subscribe(token);
      }).catchError((onError) {
        log('[getToken] onError: $onError', tag);
      });
    }

    if (!isEmpty(token)) {
      subscribe(token);
    }

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      subscribe(newToken);
    });

    FirebaseMessaging.onMessage.listen((remoteMessage) {
      log('[onMessage] message: ${remoteMessage.data}', tag);
      showNotification(remoteMessage);
    });

    // TODO test after fix https://github.com/FirebaseExtended/flutterfire/issues/4898
    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpenedApp] remoteMessage: $remoteMessage', tag);
      onNotificationClicked?.call(jsonEncode(remoteMessage.data));
    });
  }

  subscribe(String? token) async {
    log('[subscribe] token: $token', PushNotificationsManager.tag);

    SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
    if (sharedPrefs.getSubscriptionToken() == token) {
      log('[subscribe] skip subscription for same token',
          PushNotificationsManager.tag);
      return;
    }

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.pushToken = token;

    bool isProduction =
        kIsWeb ? true : const bool.fromEnvironment('dart.vm.product');
    parameters.environment =
        isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;

    if (Platform.isAndroid || kIsWeb || Platform.isIOS || Platform.isMacOS) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
    }

    var deviceInfoPlugin = DeviceInfoPlugin();

    String? deviceId;

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

    parameters.udid = deviceId ?? const Uuid().v4();

    var packageInfo = await PackageInfo.fromPlatform();
    parameters.bundleIdentifier = packageInfo.packageName;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.tag);
      sharedPrefs.saveSubscriptionToken(token!);
      for (var subscription in cubeSubscription) {
        if (subscription.clientIdentificationSequence == token) {
          sharedPrefs.saveSubscriptionId(subscription.id!);
        }
      }
    }).catchError((error) {
      log('[subscribe] subscription ERROR: $error',
          PushNotificationsManager.tag);
    });
  }

  Future<void> unsubscribe() {
    return SharedPrefs.instance.init().then((sharedPrefs) {
      int subscriptionId = sharedPrefs.getSubscriptionId();
      if (subscriptionId != 0) {
        return deleteSubscription(subscriptionId).then((voidResult) {
          FirebaseMessaging.instance.deleteToken();
          sharedPrefs.saveSubscriptionId(0);
        });
      }
      return Future.value();
    }).catchError((onError) {
      log('[unsubscribe] ERROR: $onError', PushNotificationsManager.tag);
    });
  }

  Future<dynamic> onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    log('[onDidReceiveLocalNotification] id: $id , title: $title, body: $body, payload: $payload',
        PushNotificationsManager.tag);
    return Future.value();
  }

  Future<dynamic> onSelectNotification(String? payload) {
    log('[onSelectNotification] payload: $payload',
        PushNotificationsManager.tag);
    onNotificationClicked?.call(payload);
    return Future.value();
  }
}

showNotification(RemoteMessage message) {
  log('[showNotification] message: ${message.data}',
      PushNotificationsManager.tag);
  Map<String, dynamic> data = message.data;

  NotificationDetails buildNotificationDetails(
    int? badge,
    String threadIdentifier,
  ) {
    final DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      badgeNumber: badge,
      threadIdentifier: threadIdentifier,
    );

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

    return NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinNotificationDetails,
        macOS: darwinNotificationDetails);
  }

  var badge = int.tryParse(data['badge'].toString());
  var threadId = data['ios_thread_id'] ?? data['dialog_id'] ?? 'ios_thread_id';

  FlutterLocalNotificationsPlugin().show(
    6543,
    "Chat sample",
    data['message'].toString(),
    buildNotificationDetails(badge, threadId),
    payload: jsonEncode(data),
  );
}

@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) async {
  log('[onBackgroundMessage] message: ${message.data}',
      PushNotificationsManager.tag);
  showNotification(message);
  if (!Platform.isIOS) {
    updateBadgeCount(int.tryParse(message.data['badge'].toString()));
  }
  return Future.value();
}

Future<dynamic> onNotificationSelected(String? payload, BuildContext? context) {
  log('[onSelectNotification] payload: $payload', PushNotificationsManager.tag);

  if (context == null) return Future.value();

  log('[onSelectNotification] context != null', PushNotificationsManager.tag);

  if (payload != null) {
    return SharedPrefs.instance.init().then((sharedPrefs) {
      CubeUser? user = sharedPrefs.getUser();

      Map<String, dynamic> payloadObject = jsonDecode(payload);
      String? dialogId = payloadObject['dialog_id'];

      log("[onSelectNotification] dialog_id: $dialogId",
          PushNotificationsManager.tag);

      getDialogs({'id': dialogId}).then((dialogs) {
        if (dialogs?.items != null && dialogs!.items.isNotEmpty) {
          CubeDialog dialog = dialogs.items.first;

          Navigator.pushNamed(context, 'chat_dialog',
              arguments: {userArgName: user, dialogArgName: dialog});
        }
      });
    });
  } else {
    return Future.value();
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  log('[notificationTapBackground] payload: ${notificationResponse.payload}');
}
