import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/configs.dart' as utils;
import '../utils/pref_util.dart';
import 'select_opponents_screen.dart';

class LoginScreen extends StatelessWidget {
  static const String TAG = "LoginScreen";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false, title: Text('Conference calls')),
      body: BodyLayout(),
    );
  }
}

class BodyLayout extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return BodyState();
  }
}

class BodyState extends State<BodyLayout> {
  static const String TAG = "LoginScreen.BodyState";

  bool _isLoginContinues = false;
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    log("initState", TAG);

    _loginWithSavedUserIfExist();

    CallManager.startCallIfNeed(context);
  }

  void _loginWithSavedUserIfExist() {
    SharedPrefs.getUser().then((savedUser) {
      if (savedUser != null) {
        _loginToCC(context, savedUser, savedUser: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    log("build", TAG);

    return Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Select user to login:",
            style: TextStyle(
              fontSize: 22,
            ),
          ),
          Expanded(
            child: _getUsersList(context),
          ),
        ],
      ),
    );
  }

  Widget _getUsersList(BuildContext context) {
    log("[_getUsersList]", TAG);
    final users = utils.users;

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return Card(
          color: _isLoginContinues ? Colors.white70 : Colors.white,
          child: ListTile(
            title: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    users[index].fullName!,
                    style: TextStyle(
                        color: _isLoginContinues
                            ? Colors.black26
                            : Colors.black87),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    height: 18,
                    width: 18,
                    child: Visibility(
                      visible: _isLoginContinues &&
                          users[index].id == _selectedUserId,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _loginToCC(
              context,
              users[index],
            ),
          ),
        );
      },
    );
  }

  _loginToCC(BuildContext context, CubeUser user, {bool savedUser = false}) {
    log('[_loginToCC]', TAG);
    if (_isLoginContinues) return;

    if (CubeSessionManager.instance.isActiveSessionValid() &&
        CubeChatConnection.instance.chatConnectionState ==
            CubeChatConnectionState.Ready &&
        CubeChatConnection.instance.currentUser?.id == user.id) {
      _goSelectOpponentsScreen(context, user);
      return;
    }

    setState(() {
      _isLoginContinues = true;
      _selectedUserId = user.id;
    });

    if (CubeSessionManager.instance.isActiveSessionValid() &&
        CubeSessionManager.instance.activeSession?.userId != null &&
        CubeSessionManager.instance.activeSession?.userId == user.id) {
      _loginToCubeChat(context, user);
    } else {
      createSession(user).then((cubeSession) {
        if (!savedUser) {
          SharedPrefs.saveNewUser(user);
          CallManager.instance.init(context);
        }
        _loginToCubeChat(context, user);
      }).catchError((onError) {
        _processLoginError(onError);
      });
    }
  }

  void _loginToCubeChat(BuildContext context, CubeUser user) {
    log('[_loginToCubeChat]', TAG);
    CubeChatConnection.instance.login(user).then((cubeUser) {
      if (mounted) {
        setState(() {
          _isLoginContinues = false;
          _selectedUserId = 0;
        });
        _goSelectOpponentsScreen(context, cubeUser);
      }
    }).catchError((onError) {
      _processLoginError(onError);
    });
  }

  void _processLoginError(exception) {
    log("Login error $exception", TAG);
    if (!mounted) return;

    setState(() {
      _isLoginContinues = false;
      _selectedUserId = 0;
    });

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login Error"),
            content: Text("Something went wrong during login to ConnectyCube"),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          );
        });
  }

  void _goSelectOpponentsScreen(BuildContext context, CubeUser cubeUser) {
    if (!CallManager.instance.hasActiveCall()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SelectOpponentsScreen(cubeUser),
        ),
      );
    }
  }

  @override
  void dispose() {
    log("[dispose]", TAG);

    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    log("[deactivate]", TAG);
  }

  @override
  void activate() {
    super.activate();
    log("[activate]", TAG);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log("[didChangeDependencies]", TAG);
  }
}
