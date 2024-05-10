import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'platform_api_utils.dart'
    if (dart.library.html) 'platform_api_utils_web.dart'
    if (dart.library.io) 'platform_api_utils_io.dart';

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
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            child: KeyboardListener(
              focusNode: FocusNode(onKeyEvent: (FocusNode node, KeyEvent evt) {
                if (evt.logicalKey == LogicalKeyboardKey.escape) {
                  if (evt is KeyDownEvent) {
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

bool get isVideoAttachmentsSupported =>
    kIsWeb || !(Platform.isLinux || Platform.isWindows);

bool get isImageCompressionSupported =>
    kIsWeb || Platform.isMacOS || !isDesktop();

bool get isFBAuthSupported => kIsWeb || Platform.isMacOS || !isDesktop();

Future<CubeFile> getFileLoadingFuture(
    String path, String mimeType, String fileName,
    {bool isPublic = true}) {
  return getUploadingFilePlatformFuture(path, mimeType, fileName);
}

Future<String> getImgHash(Uint8List imageData) async {
  var image = img.decodeImage(imageData);
  return BlurHash.encode(image!, numCompX: 4, numCompY: 3).hash;
}

Future<String> getImageHashAsync(Uint8List imageData) async {
  if (isImageCompressionSupported) {
    imageData = await FlutterImageCompress.compressWithList(
      imageData,
      minHeight: 480,
      minWidth: 640,
    );
  }

  if (kIsWeb) {
    return compute(getImgHash, imageData);
  } else {
    var image = img.decodeImage(imageData);
    return BlurHash.encode(image!, numCompX: 4, numCompY: 3).hash;
  }
}
