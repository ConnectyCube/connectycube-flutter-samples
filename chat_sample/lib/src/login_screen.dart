import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../firebase_options.dart';
import 'managers/push_notifications_manager.dart';
import 'phone_auth_flow.dart';
import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'utils/platform_utils.dart' as platformUtils;
import 'utils/pref_util.dart';

class LoginScreen extends StatelessWidget {
  static const String TAG = "LoginScreen";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(automaticallyImplyLeading: false, title: Text('Chat')),
      body: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new LoginPageState();
}

// Used for controlling whether the user is loggin or creating an account
enum FormType { login, register }

class LoginPageState extends State<LoginPage> {
  static const String TAG = "_LoginPageState";
  final TextEditingController _loginFilter = new TextEditingController();
  final TextEditingController _passwordFilter = new TextEditingController();
  String _login = "";
  String _password = "";
  FormType _form = FormType
      .login; // our default setting is to login, and we should switch to creating an account when the user chooses to

  bool _isLoginContinues = false;

  List<bool> loginEmailSelection = [true, false];
  bool isEmailSelected = false;

  LoginPageState() {
    _loginFilter.addListener(_loginListen);
    _passwordFilter.addListener(_passwordListen);
  }

  void _loginListen() {
    if (_loginFilter.text.isEmpty) {
      _login = "";
    } else {
      _login = _loginFilter.text;
    }
  }

  void _passwordListen() {
    if (_passwordFilter.text.isEmpty) {
      _password = "";
    } else {
      _password = _passwordFilter.text;
    }
  }

  // Swap in between our two forms, registering and logging in
  void _formChange() async {
    setState(() {
      if (_form == FormType.register) {
        _form = FormType.login;
      } else {
        _form = FormType.register;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    SharedPrefs.instance.init().then((sharedPrefs) {
      var loginType = sharedPrefs.getLoginType();
      var user = sharedPrefs.getUser();
      if ((user != null && loginType == null) || loginType != null) {
        _loginToCCWithSavedUser(context, loginType ?? LoginType.login);
      }
    });

    loginEmailSelection = [true, false];

    isEmailSelected = loginEmailSelection[1];
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: new Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[_buildLogoField(), _initLoginWidgets()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoField() {
//    return Image.asset('assets/images/splash.png');
    return Container(
      child: Align(
        alignment: FractionalOffset.center,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 350),
              child: Image.asset('assets/images/splash.png'),
            ),
            Container(
              margin: EdgeInsets.only(left: 8),
              height: 18,
              width: 18,
              child: Visibility(
                visible: _isLoginContinues,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _initLoginWidgets() {
    return FutureBuilder<Widget>(
        future: getFilterChipsWidgets(),
        builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
          if (snapshot.hasData) {
            return snapshot.data!;
          }
          return SizedBox.shrink();
        });
  }

  Future<Widget> getFilterChipsWidgets() async {
    if (_isLoginContinues) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[_buildTextFields(), _buildButtons()],
    );
  }

  Widget _buildTextFields() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 400),
      child: Container(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: ToggleButtons(
                constraints: BoxConstraints(maxHeight: 38),
                borderColor: Colors.green,
                fillColor: Colors.green.shade400,
                borderWidth: 1,
                selectedBorderColor: Colors.green,
                selectedColor: Colors.white,
                borderRadius: BorderRadius.circular(28),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 6.0),
                    child: Text(
                      'By Login',
                      style: TextStyle(
                          color: isEmailSelected ? Colors.green : Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 6.0),
                    child: Text(
                      'By E-mail',
                      style: TextStyle(
                          color: isEmailSelected ? Colors.white : Colors.green),
                    ),
                  ),
                ],
                onPressed: (int index) {
                  setState(() {
                    for (int i = 0; i < loginEmailSelection.length; i++) {
                      loginEmailSelection[i] = i == index;
                    }
                    isEmailSelected = loginEmailSelection[1];
                  });
                },
                isSelected: loginEmailSelection,
              ),
            ),
            Container(
              child: TextField(
                keyboardType: isEmailSelected
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                controller: _loginFilter,
                decoration: InputDecoration(
                    labelText: isEmailSelected ? 'E-mail' : 'Login'),
              ),
            ),
            Container(
              child: TextField(
                keyboardType: TextInputType.visiblePassword,
                controller: _passwordFilter,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) {
                  _form == FormType.login
                      ? _loginPressed()
                      : _createAccountPressed();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 400),
      child: _form == FormType.login
          ? Container(
              margin: EdgeInsets.only(top: 8),
              child: Column(
                children: <Widget>[
                  ElevatedButton(
                    child: new Text('Login'),
                    onPressed: _loginPressed,
                  ),
                  TextButton(
                    child: new Text(
                        'Don\'t have an account? Tap here to register.'),
                    onPressed: _formChange,
                  ),
                  ...createCIPButtons(),
                ],
              ),
            )
          : Container(
              margin: EdgeInsets.only(top: 8),
              child: Column(
                children: <Widget>[
                  ElevatedButton(
                    child: new Text('Create an Account'),
                    onPressed: _createAccountPressed,
                  ),
                  TextButton(
                    child: new Text('Have an account? Click here to login.'),
                    onPressed: _formChange,
                  ),
                  ...createCIPButtons(),
                ],
              ),
            ),
    );
  }

  List<Widget> createCIPButtons() {
    return [
      Visibility(
        visible: platformUtils.isPhoneAuthSupported,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(190, 36),
          ),
          icon: Icon(
            Icons.dialpad,
          ),
          label: Text('By Phone number'),
          onPressed: () {
            platformUtils.showModal(
                context: context, child: VerifyPhoneNumber());
          },
        ),
      ),
      SizedBox(
        height: 6,
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          minimumSize: Size(190, 36),
        ),
        icon: Icon(
          Icons.facebook,
          color: Colors.blue.shade700,
        ),
        label: Text(
          'By Facebook',
          style: TextStyle(color: Colors.blue.shade700),
        ),
        onPressed: () async {
          if (platformUtils.isFBAuthSupported) {
            var result = await FacebookAuth.instance
                .login(permissions: ['email', 'public_profile']);
            log('[Facebook login] result received ${result.accessToken?.toJson().toString()}',
                TAG);

            if (result.status == LoginStatus.success) {
              SharedPrefs.instance.saveLoginType(LoginType.facebook);
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil('login', (route) => false);
            } else {
              log('[Facebook login] result.status: ${result.status}');
              log('[Facebook login] result.message: ${result.message}');
            }
          } else {
            Fluttertoast.showToast(
                msg:
                    'Facebook authentication is temporarily not supported on the current platform');
          }
        },
      ),
    ];
  }

  void _loginPressed() {
    print('login with $_login and $_password');
    var userToLogin = CubeUser();
    if (isEmailSelected) {
      userToLogin.email = _login;
    } else {
      userToLogin.login = _login;
    }

    userToLogin.password = _password;

    _loginToCC(context, userToLogin, saveUser: true);
  }

  void _createAccountPressed() {
    print('create an user with $_login and $_password');
    var userToSignUp = CubeUser();
    if (isEmailSelected) {
      userToSignUp.email = _login;
    } else {
      userToSignUp.login = _login;
    }

    userToSignUp.password = _password;
    userToSignUp.fullName = _login;

    _signInCC(context, userToSignUp);
  }

  _signInCC(BuildContext context, CubeUser user) async {
    if (_isLoginContinues) return;

    setState(() {
      _isLoginContinues = true;
    });
    if (!CubeSessionManager.instance.isActiveSessionValid()) {
      try {
        await createSession();
      } catch (error) {
        _processLoginError(error);
      }
    }
    signUp(user).then((newUser) {
      print("signUp newUser $newUser");
      user.id = newUser.id;
      SharedPrefs.instance.saveNewUser(
          user, isEmailSelected ? LoginType.email : LoginType.login);
      signIn(user).then((result) {
        PushNotificationsManager.instance.init();
        _loginToCubeChat(context, user);
      });
    }).catchError((exception) {
      _processLoginError(exception);
    });
  }

  _loginToCC(BuildContext context, CubeUser user, {bool saveUser = false}) {
    print("_loginToCC user: $user");
    if (_isLoginContinues) return;
    setState(() {
      _isLoginContinues = true;
    });

    createSession(user).then((cubeSession) async {
      print("createSession cubeSession: $cubeSession");
      var tempUser = user;
      user = cubeSession.user!..password = tempUser.password;
      if (saveUser)
        SharedPrefs.instance.init().then((sharedPrefs) {
          sharedPrefs.saveNewUser(
              user, isEmailSelected ? LoginType.email : LoginType.login);
        });

      PushNotificationsManager.instance.init();

      _loginToCubeChat(context, user);
    }).catchError((error) {
      _processLoginError(error);
    });
  }

  _loginToCCWithSavedUser(BuildContext context, LoginType loginType) async {
    log("[_loginToCCWithSavedUser] user: $loginType");
    if (_isLoginContinues) return;
    setState(() {
      _isLoginContinues = true;
    });

    Future<CubeUser>? signInFuture;
    if (loginType == LoginType.phone) {
      var phoneAuthToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (phoneAuthToken == null) {
        setState(() {
          _isLoginContinues = false;
        });

        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error'),
                content: Text(
                    'Your Phone authentication session was expired, please refresh it by second login using your phone number'),
                actions: <Widget>[
                  TextButton(
                    child: Text('Retry'),
                    onPressed: () {
                      _loginToCCWithSavedUser(context, LoginType.phone);
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("Ok"),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              );
            });

        return;
      }

      signInFuture = createSession().then((cubeSession) {
        return signInUsingFirebasePhone(
                DefaultFirebaseOptions.currentPlatform.projectId,
                phoneAuthToken)
            .then((cubeUser) {
          return SharedPrefs.instance.init().then((sharedPrefs) {
            sharedPrefs.saveNewUser(cubeUser, LoginType.phone);
            return cubeUser
              ..password = CubeSessionManager.instance.activeSession?.token;
          });
        });
      });
    } else if (loginType == LoginType.login || loginType == LoginType.email) {
      signInFuture = SharedPrefs.instance.init().then((sharedPrefs) {
        var savedUser = sharedPrefs.getUser();
        return createSession(savedUser).then((value) {
          return savedUser!;
        });
      });
    } else if (loginType == LoginType.facebook) {
      final AccessToken? accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken == null) {
        setState(() {
          _isLoginContinues = false;
        });

        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error'),
                content: Text(
                    'Facebook session was expired. For continue please refresh your Facebook session by second login.'),
                actions: <Widget>[
                  TextButton(
                    child: Text('Retry'),
                    onPressed: () {
                      _loginToCCWithSavedUser(context, LoginType.facebook);
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("Ok"),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              );
            });

        return;
      } else {
        signInFuture = createSession().then((cubeSession) {
          return signInUsingSocialProvider(
            CubeProvider.FACEBOOK,
            accessToken.token,
          ).then((cubeUser) {
            return SharedPrefs.instance.init().then((sharedPrefs) {
              sharedPrefs.saveNewUser(cubeUser, LoginType.facebook);
              return cubeUser
                ..password = CubeSessionManager.instance.activeSession?.token;
            });
          });
        });
      }
    }

    signInFuture?.then((cubeUser) {
      PushNotificationsManager.instance.init();

      _loginToCubeChat(context, cubeUser);
    }).catchError((error) {
      _processLoginError(error);
    });
  }

  _loginToCubeChat(BuildContext context, CubeUser user) {
    log("_loginToCubeChat user $user");
    CubeChatConnectionSettings.instance.totalReconnections = 0;
    CubeChatConnection.instance.login(user).then((cubeUser) {
      _isLoginContinues = false;
      _goDialogScreen(context, cubeUser);
    }).catchError((error) {
      _processLoginError(error);
    });
  }

  void _processLoginError(exception) {
    log("Login error $exception", TAG);
    setState(() {
      _isLoginContinues = false;
    });
    showDialogError(exception, context);
  }

  void _goDialogScreen(BuildContext context, CubeUser cubeUser) async {
    log("_goDialogScreen");
    FlutterLocalNotificationsPlugin()
        .getNotificationAppLaunchDetails()
        .then((details) {
      log("getNotificationAppLaunchDetails");
      String? payload = details!.notificationResponse?.payload;

      log("getNotificationAppLaunchDetails, payload: $payload");

      var dialogId;
      if (payload == null) {
        dialogId = SharedPrefs.instance.getSelectedDialogId();
        log("getNotificationAppLaunchDetails, selectedDialogId: $dialogId");
      } else {
        Map<String, dynamic> payloadObject = jsonDecode(payload);
        dialogId = payloadObject['dialog_id'];
      }

      if (dialogId != null && dialogId.isNotEmpty) {
        getDialogs({'id': dialogId}).then((dialogs) {
          if (dialogs?.items != null && dialogs!.items.isNotEmpty) {
            CubeDialog dialog = dialogs.items.first;
            navigateToNextScreen(cubeUser, dialog);
          } else {
            navigateToNextScreen(cubeUser, null);
          }
        }).catchError((onError) {
          navigateToNextScreen(cubeUser, null);
        });
      } else {
        navigateToNextScreen(cubeUser, null);
      }
    }).catchError((onError) {
      log("getNotificationAppLaunchDetails ERROR");
      navigateToNextScreen(cubeUser, null);
    });
  }

  void navigateToNextScreen(CubeUser cubeUser, CubeDialog? dialog) {
    SharedPrefs.instance.saveSelectedDialogId('');
    Navigator.pushReplacementNamed(
      context,
      'select_dialog',
      arguments: {USER_ARG_NAME: cubeUser, DIALOG_ARG_NAME: dialog},
    );

    if (dialog != null && !platformUtils.isDesktop()) {
      Navigator.pushNamed(context, 'chat_dialog',
          arguments: {USER_ARG_NAME: cubeUser, DIALOG_ARG_NAME: dialog});
    }
  }
}
