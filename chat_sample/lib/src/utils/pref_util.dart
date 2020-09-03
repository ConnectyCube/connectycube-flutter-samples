import 'dart:async';

import 'package:connectycube_sdk/connectycube_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefUserLogin = "pref_user_login";
const String prefUserPsw = "pref_user_psw";
const String prefUserName = "pref_user_name";
const String prefUserId = "pref_user_id";
const String prefUserAvatar = "pref_user_avatar";

class SharedPrefs {
  static final SharedPrefs _instance = SharedPrefs._internal();
  SharedPreferences prefs;

  SharedPrefs._internal();

  bool inited = false;

  static SharedPrefs get instance => _instance;

  Future<void> init() async {
    Completer completer = Completer();
    if (inited) {
      completer.complete();
    } else {
      prefs = await SharedPreferences.getInstance();
      inited = true;
      completer.complete();
    }
    return completer.future;
  }

  saveNewUser(CubeUser cubeUser) {
    prefs.clear();
    prefs.setString(prefUserLogin, cubeUser.login);
    prefs.setString(prefUserPsw, cubeUser.password);
    prefs.setString(prefUserName, cubeUser.fullName);
    prefs.setInt(prefUserId, cubeUser.id);
    if (cubeUser.avatar != null)
      prefs.setString(prefUserAvatar, cubeUser.avatar);
  }

  updateUser(CubeUser cubeUser) {
    if (cubeUser.password != null)
      prefs.setString(prefUserPsw, cubeUser.password);
    if (cubeUser.login != null) prefs.setString(prefUserLogin, cubeUser.login);
    if (cubeUser.fullName != null)
      prefs.setString(prefUserName, cubeUser.fullName);
    if (cubeUser.avatar != null)
      prefs.setString(prefUserAvatar, cubeUser.avatar);
  }

  CubeUser getUser() {
    if (prefs.get(prefUserLogin) == null) return null;
    var user = CubeUser();
    user.login = prefs.get(prefUserLogin);
    user.password = prefs.get(prefUserPsw);
    user.fullName = prefs.get(prefUserName);
    user.id = prefs.get(prefUserId);
    user.avatar = prefs.get(prefUserAvatar);
    return user;
  }

  deleteUser() {
    prefs.clear();
  }
}
