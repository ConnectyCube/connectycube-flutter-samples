import 'dart:async';
import 'dart:collection';

import 'package:connectycube_sdk/connectycube_chat.dart';
import 'package:flutter/material.dart';

void showDialogError(exception, context) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text("Something went wrong $exception"),
          actions: <Widget>[
            FlatButton(
              child: Text("OK"),
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
          title: Text("Alert"),
          content: Text(msg),
          actions: <Widget>[
            FlatButton(
              child: Text("OK"),
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
    var result = await getAllUsersByIds(ids);
    users.addAll(Map.fromIterable(result.items,
        key: (item) => item.id, value: (item) => item));
  } catch (ex) {
    log("exception= $ex");
  }
  completer.complete(users);
  return completer.future;
}
