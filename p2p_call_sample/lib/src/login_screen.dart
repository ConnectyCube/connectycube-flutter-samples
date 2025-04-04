import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'config.dart' as config;
import 'select_opponents_screen.dart';
import 'utils/pref_util.dart';

class LoginScreen extends StatelessWidget {
  static const String tag = "LoginScreen";

  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false, title: const Text('P2P calls')),
      body: const BodyLayout(),
    );
  }
}

class BodyLayout extends StatefulWidget {
  const BodyLayout({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BodyState();
  }
}

class BodyState extends State<BodyLayout> {
  static const String tag = "LoginScreen.BodyState";

  bool _isLoginContinues = false;
  int? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
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

  @override
  void initState() {
    super.initState();

    SharedPrefs.getUser().then((loggedUser) {
      if (loggedUser != null) {
        _loginToCC(context, loggedUser);
      }
    });
  }

  Widget _getUsersList(BuildContext context) {
    final users = config.users;

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
                    margin: const EdgeInsets.only(left: 8),
                    height: 18,
                    width: 18,
                    child: Visibility(
                      visible: _isLoginContinues &&
                          users[index].id == _selectedUserId,
                      child: const CircularProgressIndicator(
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

  _loginToCC(BuildContext context, CubeUser user) {
    if (_isLoginContinues) return;

    setState(() {
      _isLoginContinues = true;
      _selectedUserId = user.id;
    });

    if (CubeSessionManager.instance.isActiveSessionValid() &&
        CubeSessionManager.instance.activeSession!.user != null) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        setState(() {
          _isLoginContinues = false;
          _selectedUserId = 0;
        });
        _goSelectOpponentsScreen(context, user);
      } else {
        _loginToCubeChat(context, user);
      }
    } else {
      createSession(user).then((cubeSession) {
        _loginToCubeChat(context, user);
      }).catchError((exception) {
        _processLoginError(exception);
      });
    }
  }

  void _loginToCubeChat(BuildContext context, CubeUser user) {
    CubeChatConnection.instance.login(user).then((cubeUser) {
      SharedPrefs.saveNewUser(user);
      setState(() {
        _isLoginContinues = false;
        _selectedUserId = 0;
      });
      _goSelectOpponentsScreen(context, cubeUser);
    }).catchError((exception) {
      _processLoginError(exception);
    });
  }

  void _processLoginError(exception) {
    log("Login error $exception", tag);

    setState(() {
      _isLoginContinues = false;
      _selectedUserId = 0;
    });

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Login Error"),
            content:
                const Text("Something went wrong during login to ConnectyCube"),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          );
        });
  }

  void _goSelectOpponentsScreen(BuildContext context, CubeUser cubeUser) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SelectOpponentsScreen(cubeUser),
      ),
    );
  }
}
