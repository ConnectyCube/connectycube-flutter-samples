import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'managers/push_notifications_manager.dart';
import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'utils/pref_util.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  final CubeUser currentUser;

  const SettingsScreen(this.currentUser, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          automaticallyImplyLeading: false,
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
        ),
        body: BodyLayout(currentUser),
        resizeToAvoidBottomInset: false);
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;

  const BodyLayout(this.currentUser, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState();
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String tag = "_BodyLayoutState";

  var _isUsersContinues = false;
  String? _avatarUrl = "";
  final TextEditingController _loginFilter = TextEditingController();
  final TextEditingController _nameFilter = TextEditingController();
  final TextEditingController _emailFilter = TextEditingController();
  String _login = "";
  String _name = "";
  String _email = "";

  LoginType loginType = LoginType.login;

  _BodyLayoutState() {
    _loginFilter.addListener(_loginListen);
    _nameFilter.addListener(_nameListen);
    _emailFilter.addListener(_emailListen);
  }

  @override
  void initState() {
    super.initState();
    loginType = SharedPrefs.instance.getLoginType() ?? LoginType.login;

    _nameFilter.text = widget.currentUser.fullName ?? '';
    _loginFilter.text = widget.currentUser.login ?? '';
    _emailFilter.text = widget.currentUser.email ?? '';
  }

  void _loginListen() {
    if (_loginFilter.text.isEmpty) {
      _login = "";
    } else {
      _login = _loginFilter.text.trim();
    }
  }

  void _nameListen() {
    if (_nameFilter.text.isEmpty) {
      _name = "";
    } else {
      _name = _nameFilter.text.trim();
    }
  }

  void _emailListen() {
    if (_emailFilter.text.isEmpty) {
      _email = "";
    } else {
      _email = _emailFilter.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(60),
              child: Column(
                children: [
                  _buildAvatarFields(),
                  _buildTextFields(),
                  _buildButtons(),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Visibility(
                      maintainSize: false,
                      maintainAnimation: false,
                      maintainState: false,
                      visible: _isUsersContinues,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFields() {
    Widget avatarCircle = getUserAvatarWidget(widget.currentUser, 50);

    return Stack(
      children: <Widget>[
        InkWell(
          splashColor: greyColor2,
          borderRadius: BorderRadius.circular(45),
          onTap: () => _chooseUserImage(),
          child: avatarCircle,
        ),
        Positioned(
          top: 55.0,
          right: 35.0,
          child: RawMaterialButton(
            onPressed: () {
              _chooseUserImage();
            },
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(5.0),
            shape: const CircleBorder(),
            child: const Icon(
              Icons.mode_edit,
              size: 20.0,
            ),
          ),
        ),
      ],
    );
  }

  _chooseUserImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    var uploadImageFuture = getUploadingMediaFuture(result);

    uploadImageFuture.then((cubeFile) {
      _avatarUrl = cubeFile.getPublicUrl();
      setState(() {
        widget.currentUser.avatar = _avatarUrl;
      });
    }).catchError((exception) {
      _processUpdateUserError(exception);
    });
  }

  Widget _buildTextFields() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _nameFilter,
          decoration: const InputDecoration(labelText: 'Change name'),
        ),
        Visibility(
          visible: loginType == LoginType.login || loginType == LoginType.email,
          child: TextField(
            controller: _loginFilter,
            decoration: const InputDecoration(labelText: 'Change login'),
          ),
        ),
        Visibility(
          visible: loginType == LoginType.login || loginType == LoginType.email,
          child: TextField(
            controller: _emailFilter,
            decoration: const InputDecoration(labelText: 'Change e-mail'),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: <Widget>[
        const SizedBox(
          height: 6,
        ),
        ElevatedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(120, 36),
          ),
          onPressed: _updateUser,
          child: const Text('Save'),
        ),
        const SizedBox(
          height: 6,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(160, 36),
          ),
          icon: const Icon(
            Icons.logout,
          ),
          label: const Text('Logout'),
          onPressed: _logout,
        ),
        const SizedBox(
          height: 6,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade300,
            minimumSize: const Size(160, 36),
          ),
          icon: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
          label: const Text(
            'Delete user',
            style: TextStyle(color: Colors.red),
          ),
          onPressed: _deleteUserPressed,
        ),
      ],
    );
  }

  void _updateUser() {
    log('_updateUser user with login: $_login, name: $_name, e-mail: $_email');
    if (_login.isEmpty &&
        _name.isEmpty &&
        _avatarUrl!.isEmpty &&
        _email.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    var userToUpdate = CubeUser()..id = widget.currentUser.id;

    if (_name.isNotEmpty) userToUpdate.fullName = _name;
    if (_login.isNotEmpty) userToUpdate.login = _login;
    if (_email.isNotEmpty) userToUpdate.email = _email;
    if (_avatarUrl!.isNotEmpty) userToUpdate.avatar = _avatarUrl;
    setState(() {
      _isUsersContinues = true;
    });
    updateUser(userToUpdate).then((user) {
      SharedPrefs.instance.updateUser(user);
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        _isUsersContinues = false;
      });
    }).catchError((exception) {
      _processUpdateUserError(exception);
    });
  }

  void _logout() {
    log('_logout $_login and $_name');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want logout current user"),
          actions: <Widget>[
            TextButton(
              child: const Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("OK"),
              onPressed: () async {
                await PushNotificationsManager.instance.unsubscribe();
                signOut().then(
                  (voidValue) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).catchError(
                  (onError) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).whenComplete(() {
                  CubeChatConnection.instance.destroy();
                  if (loginType == LoginType.phone) {
                    FirebaseAuth.instance.currentUser
                        ?.unlink(PhoneAuthProvider.PROVIDER_ID);
                    FirebaseAuth.instance.currentUser?.delete();
                  } else if (loginType == LoginType.facebook) {
                    FacebookAuth.instance.logOut();
                  } else if (loginType == LoginType.google) {
                    FirebaseAuth.instance.currentUser?.delete();
                  }
                  SharedPrefs.instance.deleteUser();
                  Navigator.pop(context); // cancel current screen
                  _navigateToLoginScreen(context);
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteUserPressed() {
    log('_deleteUserPressed ${_login.isNotEmpty ? _login : _email}');
    _userDelete();
  }

  void _userDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete user"),
          content: const Text("Are you sure you want to delete current user?"),
          actions: <Widget>[
            TextButton(
              child: const Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("OK"),
              onPressed: () async {
                CubeChatConnection.instance.destroy();
                await SharedPrefs.instance.deleteUser();

                await PushNotificationsManager.instance
                    .unsubscribe()
                    .whenComplete(() {
                  deleteUser(widget.currentUser.id!).whenComplete(() async {
                    _navigateToLoginScreen(context);
                  });
                });
              },
            ),
          ],
        );
      },
    );
  }

  _navigateToLoginScreen(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
  }

  void _processUpdateUserError(exception) {
    log("_processUpdateUserError error $exception", tag);
    setState(() {
      _isUsersContinues = false;
    });
    showDialogError(exception, context);
  }
}
