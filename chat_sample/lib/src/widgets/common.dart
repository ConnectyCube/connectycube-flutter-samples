import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectycube_sdk/connectycube_chat.dart';
import 'package:flutter/material.dart';

import '../utils/consts.dart';

Widget getAvatarTextWidget(bool condition, String? text, {double? fontSize}) {
  if (condition) {
    return const SizedBox.shrink();
  } else {
    return Text(
      isEmpty(text) ? '?' : text!,
      style: TextStyle(fontSize: fontSize ?? 30, color: Colors.green),
    );
  }
}

Widget getUserAvatarWidget(CubeUser? cubeUser, double radius,
    {Widget? placeholder, Widget? errorWidget}) {
  return getAvatarWidget(cubeUser?.avatar, cubeUser?.fullName, radius,
      placeholder: placeholder, errorWidget: errorWidget);
}

Widget getDialogAvatarWidget(CubeDialog? cubeDialog, double radius,
    {Widget? placeholder, Widget? errorWidget}) {
  return getAvatarWidget(cubeDialog?.photo, cubeDialog?.name, radius,
      placeholder: placeholder, errorWidget: errorWidget);
}

Widget getAvatarWidget(String? imageUrl, String? name, double radius,
    {Widget? placeholder, Widget? errorWidget}) {
  return CircleAvatar(
    backgroundColor: const Color.fromARGB(20, 100, 100, 100),
    radius: radius,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: imageUrl ?? '',
        errorWidget: (context, url, error) {
          return errorWidget ??
              placeholder ??
              Center(
                  child: Container(
                      child: getAvatarTextWidget(
                          false, name?.substring(0, 2).toUpperCase() ?? '?',
                          fontSize: radius)));
        },
        placeholder: (context, url) {
          return placeholder ??
              Center(
                  child: Container(
                      child: getAvatarTextWidget(
                          false, name?.substring(0, 2).toUpperCase() ?? '?',
                          fontSize: radius)));
        },
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
      ),
    ),
  );
}

Widget getMessageStateWidget(MessageState? state) {
  Widget result;

  switch (state) {
    case MessageState.read:
      result = const Stack(children: <Widget>[
        Icon(
          Icons.check_rounded,
          size: 15.0,
          color: Colors.green,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 4,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 15.0,
            color: Colors.green,
          ),
        )
      ]);

      break;
    case MessageState.delivered:
      result = const Stack(children: <Widget>[
        Icon(
          Icons.check_rounded,
          size: 15.0,
          color: greyColor,
        ),
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(
            Icons.check_rounded,
            size: 15.0,
            color: greyColor,
          ),
        )
      ]);

      break;
    case MessageState.sent:
      result = const Icon(
        Icons.check_rounded,
        size: 15.0,
        color: greyColor,
      );

      break;
    default:
      result = const SizedBox.shrink();

      break;
  }

  return result;
}
