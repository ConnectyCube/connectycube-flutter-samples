import 'dart:async';

import 'package:connectycube_sdk/connectycube_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefUserLogin = "pref_user_login";
const String prefUserPsw = "pref_user_psw";
const String prefUserName = "pref_user_name";
const String prefUserId = "pref_user_id";
const String prefUserAvatar = "pref_user_avatar";
const String prefSubscriptionToken = "pref_subscription_token";
const String prefSubscriptionId = "pref_subscription_id";

class SharedPrefs {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> getPrefs() async {
    Completer<SharedPreferences> completer = Completer();
    if (_prefs != null) {
      completer.complete(_prefs);
    } else {
      _prefs = await SharedPreferences.getInstance();
      completer.complete(_prefs);
    }
    return completer.future;
  }

  static Future<bool> saveNewUser(CubeUser cubeUser) {
    return getPrefs().then((prefs) {
      prefs.clear();
      prefs.setString(prefUserLogin, cubeUser.login!);
      prefs.setString(prefUserPsw, cubeUser.password!);
      prefs.setString(prefUserName, cubeUser.fullName!);
      prefs.setInt(prefUserId, cubeUser.id!);
      if (cubeUser.avatar != null)
        prefs.setString(prefUserAvatar, cubeUser.avatar!);

      return Future.value(true);
    });
  }

  static Future<bool> updateUser(CubeUser cubeUser) {
    return getPrefs().then((prefs) {
      if (cubeUser.password != null)
        prefs.setString(prefUserPsw, cubeUser.password!);
      if (cubeUser.login != null)
        prefs.setString(prefUserLogin, cubeUser.login!);
      if (cubeUser.fullName != null)
        prefs.setString(prefUserName, cubeUser.fullName!);
      if (cubeUser.avatar != null)
        prefs.setString(prefUserAvatar, cubeUser.avatar!);

      return Future.value(true);
    });
  }

  static Future<CubeUser?> getUser() {
    return getPrefs().then((prefs) {
      if (prefs.getString(prefUserLogin) == null) return Future.value();
      var user = CubeUser();
      user.login = prefs.getString(prefUserLogin);
      user.password = prefs.getString(prefUserPsw);
      user.fullName = prefs.getString(prefUserName);
      user.id = prefs.getInt(prefUserId);
      user.avatar = prefs.getString(prefUserAvatar);
      return Future.value(user);
    });
  }

  static Future<bool> deleteUserData() {
    return getPrefs().then((prefs) {
      return prefs.clear();
    });
  }

  static Future<bool> saveSubscriptionToken(String token) {
    return getPrefs().then((prefs) {
      return prefs.setString(prefSubscriptionToken, token);
    });
  }

  static Future<String> getSubscriptionToken() {
    return getPrefs().then((prefs) {
      return Future.value(prefs.getString(prefSubscriptionToken) ?? "");
    });
  }

  static Future<bool> saveSubscriptionId(int id) {
    return getPrefs().then((prefs) {
      return prefs.setInt(prefSubscriptionId, id);
    });
  }

  static Future<int> getSubscriptionId() {
    return getPrefs().then((prefs) {
      return Future.value(prefs.getInt(prefSubscriptionId) ?? 0);
    });
  }
}
