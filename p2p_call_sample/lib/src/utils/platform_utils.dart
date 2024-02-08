import 'package:connectycube_sdk/connectycube_core.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

Future<bool> initForegroundService() async {
  if (Platform.isAndroid) {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'P2P Calls sample',
      notificationText: 'Screen sharing is in progress',
      notificationImportance: AndroidNotificationImportance.Default,
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
    var sdkInt = androidInfo.version.sdkInt!;

    if (sdkInt >= 31) {
      if (await Permission.systemAlertWindow.isDenied) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Expanded(
              child: AlertDialog(
                title: Text('Permission required'),
                content: Text(
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
                    child: Text(
                      'Allow',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Later',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }
  }
}

requestNotificationsPermission() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
    var isPermissionGranted = await Permission.notification.isGranted;
    log('isPermissionGranted = $isPermissionGranted', 'platform_utils');
    if (!isPermissionGranted) {
      await Permission.notification.request();
    }
  }
}
