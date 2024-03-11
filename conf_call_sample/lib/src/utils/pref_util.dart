import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

const String prefUserLogin = 'conf_pref_user_login';
const String prefUserPsw = 'conf_pref_user_psw';
const String prefUserName = 'conf_pref_user_name';
const String prefUserId = 'conf_pref_user_id';
const String prefUserAvatar = 'conf_pref_user_avatar';
const String prefUserIsGuest = 'conf_pref_user_is_guest';
const String prefUserCreatedAt = 'conf_pref_user_created_at';
const String prefSession = 'conf_pref_session';
const String prefSubscriptionToken = 'conf_pref_subscription_token';
const String prefSubscriptionId = 'conf_pref_subscription_id';

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

  static Future<bool> saveSession(CubeSession cubeSession) {
    return getPrefs().then((prefs) {
      return prefs.setString(prefSession, jsonEncode(cubeSession));
    });
  }

  static Future<CubeSession?> getSession() {
    return getPrefs().then((prefs) {
      var sessionJsonString = prefs.getString(prefSession);
      if (sessionJsonString == null) return null;

      var cubeSession = CubeSession.fromJson(jsonDecode(sessionJsonString));

      var sessionExpirationDate = cubeSession.tokenExpirationDate;
      if (sessionExpirationDate?.isBefore(DateTime.now()) ?? true) {
        prefs.remove(prefSession);
        return null;
      }
      return cubeSession;
    });
  }

  static Future<bool> deleteSessionData() {
    return getPrefs().then((prefs) {
      return prefs.remove(prefSession);
    });
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
      prefs.setBool(prefUserIsGuest, cubeUser.isGuest ?? false);
      prefs.setInt(
          prefUserCreatedAt, cubeUser.createdAt?.millisecondsSinceEpoch ?? -1);

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

      var userIsGuest = prefs.getBool(prefUserIsGuest) ?? false;
      var userCreatedAt = prefs.getInt(prefUserCreatedAt) ?? -1;

      if (userIsGuest && userCreatedAt != -1) {
        var currentDate = DateTime.now().millisecondsSinceEpoch;

        var lifeTime = currentDate - (userCreatedAt + 2 * 60 * 60 * 1000);
        var day = 24 * 60 * 60 * 1000;

        if (lifeTime >= day) {
          return null;
        }
      }

      var user = CubeUser()
        ..login = prefs.getString(prefUserLogin)
        ..password = prefs.getString(prefUserPsw)
        ..fullName = prefs.getString(prefUserName)
        ..id = prefs.getInt(prefUserId)
        ..avatar = prefs.getString(prefUserAvatar)
        ..isGuest = userIsGuest
        ..createdAt = DateTime.fromMillisecondsSinceEpoch(userCreatedAt);

      return user;
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
