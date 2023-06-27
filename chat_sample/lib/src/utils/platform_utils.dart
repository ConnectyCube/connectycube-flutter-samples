import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:universal_io/io.dart';

bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

void showModal({
  required BuildContext context,
  required Widget child,
  double maxWidth = 600,
}) {
  if (isDesktop()) {
    showDialog(
        context: context,
        builder: (BuildContext cxt) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            child: RawKeyboardListener(
              focusNode: FocusNode(onKey: (FocusNode node, RawKeyEvent evt) {
                if (evt.logicalKey == LogicalKeyboardKey.escape) {
                  if (evt is RawKeyDownEvent) {
                    Navigator.pop(context);
                    return KeyEventResult.handled;
                  }
                }

                return KeyEventResult.ignored;
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child),
              ),
            ),
          );
        });
  } else if (Platform.isAndroid) {
    showMaterialModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        expand: true,
        builder: (context) {
          return child;
        });
  } else if (Platform.isIOS) {
    showCupertinoModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        expand: true,
        builder: (context) {
          return child;
        });
  }
}

void updateBadgeCount(int? count) {
  FlutterAppBadger.isAppBadgeSupported().then((isBadgesSupported) {
    if (isBadgesSupported) {
      if (count == null || count == 0) {
        FlutterAppBadger.removeBadge();
      } else {
        FlutterAppBadger.updateBadgeCount(count);
      }
    }
  });
}

bool get isPhoneAuthSupported => kIsWeb || !isDesktop();
