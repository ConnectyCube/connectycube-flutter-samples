import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/configs.dart' as utils;
import '../utils/consts.dart';
import '../utils/pref_util.dart';

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

  StreamSubscription<CubeChatConnectionState>? _connectionStareSubscription;
  Function()? _successChatLoginCallback;

  @override
  void initState() {
    super.initState();
    log("initState", TAG);

    _initChatConnectionListener();
    _loginWithSavedUserIfExist();

    CallManager.startCallIfNeed(context);
  }

  void _loginWithSavedUserIfExist() {
    SharedPrefs.getUser().then((savedUser) {
      if (savedUser != null) {
        if (savedUser.isGuest ?? false) {
          SharedPrefs.getSession().then((savedSession) {
            if (savedSession != null) {
              CubeSessionManager.instance.activeSession = savedSession;

              setState(() {
                _isLoginContinues = true;
                _selectedUserId = 0;
              });

              _loginToCubeChat(context, savedUser, successCallback: () {});
            }
          });
        } else {
          _loginToCC(context, savedUser, savedUser: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    log("build", TAG);

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(top: 48, bottom: 24, left: 24, right: 24),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  loginAsGuest();
                },
                child: Container(
                  width: 400,
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Visibility(
                        visible: !_isLoginContinues,
                        child: Icon(
                          Icons.add,
                          size: 18,
                        ),
                      ),
                      Visibility(
                          visible: _isLoginContinues && _selectedUserId == 0,
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ))),
                      SizedBox(width: 8),
                      Text(
                        'Login as Guest',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'or',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              Text(
                "Select user to login:",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              _getUsersList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getUsersList(BuildContext context) {
    log("[_getUsersList]", TAG);
    final users = utils.users;

    return ListView.builder(
      shrinkWrap: true,
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
        CubeSessionManager.instance.activeSession?.user?.id != null &&
        CubeSessionManager.instance.activeSession?.user?.id == user.id) {
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

  void _loginToCubeChat(BuildContext context, CubeUser user,
      {Function()? successCallback}) {
    log('[_loginToCubeChat]', TAG);
    _successChatLoginCallback = successCallback;
    CubeChatConnection.instance.login(user);
  }

  void _processLoginError(exception) {
    log("Login error $exception", TAG);
    if (!mounted) return;

    setState(() {
      _isLoginContinues = false;
      _selectedUserId = -1;
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
      Navigator.of(context).pushReplacementNamed(
        SELECT_OPPONENTS_SCREEN,
        arguments: {ARG_USER: cubeUser},
      );
    }
  }

  @override
  void dispose() {
    log("[dispose]", TAG);
    _connectionStareSubscription?.cancel();

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

  void loginAsGuest() {
    setState(() {
      _isLoginContinues = true;
      _selectedUserId = 0;
    });
    createSession(CubeUser(
            isGuest: true, fullName: 'Guest ${Random().nextInt(1024)}'))
        .then((session) {
      session.user!.password = session.token;
      _loginToCubeChat(context, session.user!, successCallback: () {
        SharedPrefs.saveNewUser(session.user!);
        SharedPrefs.saveSession(session);
      });
    }).catchError((onError) {
      _processLoginError(onError);
    });
  }

  void _initChatConnectionListener() {
    log("[_initChatConnectionListener]", TAG);
    _connectionStareSubscription =
        CubeChatConnection.instance.connectionStateStream.listen((state) {
      log("[_initChatConnectionListener] state: $state", TAG);
      if (state == CubeChatConnectionState.Ready) {
        _successChatLoginCallback?.call();

        if (mounted) {
          setState(() {
            _isLoginContinues = false;
            _selectedUserId = -1;
          });
          _goSelectOpponentsScreen(
              context, CubeChatConnection.instance.currentUser!);
        }
      } else if (state == CubeChatConnectionState.AuthenticationFailure) {
        _processLoginError(null);
      }
    });
  }
}
