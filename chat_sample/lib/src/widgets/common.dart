import 'package:flutter/cupertino.dart';

Widget getAvatarTextWidget(bool condition, String text) {
  if (condition)
    return SizedBox.shrink();
  else
    return ClipRRect(
      borderRadius: BorderRadius.circular(55),
      child: Text(
        text,
        style: TextStyle(fontSize: 30),
      ),
    );
}
