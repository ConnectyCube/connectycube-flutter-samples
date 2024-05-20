import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/pref_util.dart';

class PushNotificationsManager {
  static const tag = "PushNotificationsManager";

  static PushNotificationsManager? _instance;

  PushNotificationsManager._internal();

  static PushNotificationsManager _getInstance() {
    return _instance ??= PushNotificationsManager._internal();
  }

  factory PushNotificationsManager() => _getInstance();

  BuildContext? applicationContext;

  static PushNotificationsManager get instance => _getInstance();

  init() async {
    ConnectycubeFlutterCallKit.initEventsHandler();

    ConnectycubeFlutterCallKit.onTokenRefreshed = (token) {
      log('[onTokenRefresh] VoIP token: $token', tag);
      subscribe(token);
    };

    ConnectycubeFlutterCallKit.getToken().then((token) {
      log('[getToken] VoIP token: $token', tag);
      if (token != null) {
        subscribe(token);
      }
    });
  }

  subscribe(String token) async {
    log('[subscribe] token: $token', PushNotificationsManager.tag);

    var savedToken = await SharedPrefs.getSubscriptionToken();
    if (token == savedToken) {
      log('[subscribe] skip subscription for same token',
          PushNotificationsManager.tag);
      return;
    }

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.pushToken = token;

    parameters.environment = CubeEnvironment
        .DEVELOPMENT; // TODO used `DEVELOPMENT` environment for testing purposes
    // parameters.environment = kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT; // TODO use actual environment in the real app

    if (Platform.isAndroid) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
    } else if (Platform.isIOS) {
      parameters.channel = NotificationsChannels.APNS_VOIP;
      parameters.platform = CubePlatform.IOS;
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

    parameters.udid = deviceId;

    var packageInfo = await PackageInfo.fromPlatform();
    parameters.bundleIdentifier = packageInfo.packageName;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscriptions) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.tag);
      SharedPrefs.saveSubscriptionToken(token);
      for (var subscription in cubeSubscriptions) {
        if (subscription.device!.clientIdentificationSequence == token) {
          SharedPrefs.saveSubscriptionId(subscription.id!);
        }
      }
    }).catchError((error) {
      log('[subscribe] subscription ERROR: $error',
          PushNotificationsManager.tag);
    });
  }

  Future<void> unsubscribe() {
    return SharedPrefs.getSubscriptionId().then((subscriptionId) async {
      if (subscriptionId != 0) {
        return deleteSubscription(subscriptionId).then((voidResult) {
          SharedPrefs.saveSubscriptionId(0);
        });
      } else {
        return Future.value();
      }
    }).catchError((onError) {
      log('[unsubscribe] ERROR: $onError', PushNotificationsManager.tag);
    });
  }
}
