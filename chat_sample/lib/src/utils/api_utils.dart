import 'dart:async';
import 'dart:collection';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

import 'platform_api_utils.dart'
    if (dart.library.html) 'platform_api_utils_web.dart'
    if (dart.library.io) 'platform_api_utils_io.dart';

void showDialogError(exception, context) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text("Something went wrong: $exception"),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      });
}

void showDialogMsg(msg, context) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Alert"),
          content: Text(msg),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      });
}

class ListItem<T> {
  bool isSelected = false; //Selection property to highlight or not
  T data; //Data of the user
  ListItem(this.data); //Constructor to assign the data
}

Future<Map<int, CubeUser>> getUsersByIds(Set<int> ids) async {
  Completer<Map<int, CubeUser>> completer = Completer();
  Map<int, CubeUser> users = HashMap();
  try {
    var result =
        await (getAllUsersByIds(ids) as FutureOr<PagedResult<CubeUser>>);
    users.addAll({for (var item in result.items) item.id!: item});
  } catch (ex) {
    log("exception= $ex");
  }
  completer.complete(users);
  return completer.future;
}

Future<CubeFile> getUploadingMediaFuture(FilePickerResult result) async {
  return getUploadingMediaPlatformFuture(result);
}

Future<CubeFile> getUploadingFileFuture(
  String path,
  String mimeType,
  String fileName, {
  bool isPublic = true,
}) {
  return getUploadingFilePlatformFuture(path, mimeType, fileName,
      isPublic: isPublic);
}

void refreshBadgeCount() {
  getUnreadMessagesCount().then((result) {
    updateBadgeCount(result['total']);
  });
}
