import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_calls.dart';

import 'platform_configuration.dart'
    if (dart.library.html) 'platform_configuration_web.dart'
    if (dart.library.io) 'platform_configuration_noweb.dart';

Future<bool> initForegroundService() async {
  if (Platform.isAndroid) {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Conference Calls sample',
      notificationText: 'Screen sharing is in progress',
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon:
          AndroidResource(name: 'ic_launcher_foreground', defType: 'drawable'),
    );
    return FlutterBackground.initialize(androidConfig: androidConfig);
  } else {
    return Future.value(true);
  }
}

Future<bool> startBackgroundExecution() async {
  if (Platform.isAndroid) {
    return initForegroundService().then((_) {
      return FlutterBackground.enableBackgroundExecution();
    });
  } else {
    return Future.value(true);
  }
}

Future<bool> stopBackgroundExecution() async {
  if (Platform.isAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
    return FlutterBackground.disableBackgroundExecution();
  } else {
    return Future.value(true);
  }
}

Future<bool> hasBackgroundExecutionPermissions() async {
  if (Platform.isAndroid) {
    return FlutterBackground.hasPermissions;
  } else {
    return Future.value(true);
  }
}

Future<void> checkSystemAlertWindowPermission(BuildContext context) async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 31) {
      Permission.systemAlertWindow.isDenied.then((isDenied) {
        if (isDenied) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Permission required'),
                content: const Text(
                    'For accepting the calls in the background you should provide access to show System Alerts from the background. Would you like to do it now?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Permission.systemAlertWindow.request().then((status) {
                        if (status.isGranted) {
                          Navigator.of(context).pop();
                        }
                      });
                    },
                    child: const Text(
                      'Allow',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Later',
                    ),
                  ),
                ],
              );
            },
          );
        }
      });
    }
  }
}

requestNotificationsPermission() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
    var isPermissionGranted = await Permission.notification.isGranted;
    if (!isPermissionGranted) {
      await Permission.notification.request();
    }
  }
}

requestFullScreenIntentsPermission(BuildContext context) async {
  if (!Platform.isAndroid) return;

  var androidInfo = await DeviceInfoPlugin().androidInfo;
  var sdkInt = androidInfo.version.sdkInt;

  if (sdkInt < 34) return;

  ConnectycubeFlutterCallKit.canUseFullScreenIntent()
      .then((canUseFullScreenIntent) {
    log('[requestFullScreenIntentsPermission] canUseFullScreenIntent: $canUseFullScreenIntent',
        'platform_utils');

    if (!canUseFullScreenIntent) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Full Screen notifications Permission required'),
            content: const Text(
                'To display an Incoming call on the Lock screen, you must grant access to the Lock screen. Would you like to do it now?'),
            actions: [
              TextButton(
                onPressed: () {
                  ConnectycubeFlutterCallKit.provideFullScreenIntentAccess()
                      .then((_) {
                    Navigator.of(context).pop();
                  });
                },
                child: const Text(
                  'Grant',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Later',
                ),
              ),
            ],
          );
        },
      );
    }
  });
}

void configurePlatform() {
  configureNavigation();
}

String getAppHost() {
  return getHostUrl();
}
