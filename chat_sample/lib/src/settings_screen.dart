import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'managers/push_notifications_manager.dart';
import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'utils/pref_util.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  final CubeUser currentUser;

  SettingsScreen(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          automaticallyImplyLeading: false,
          title: Text(
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

  BodyLayout(this.currentUser);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String TAG = "_BodyLayoutState";

  final CubeUser currentUser;
  var _isUsersContinues = false;
  String? _avatarUrl = "";
  final TextEditingController _loginFilter = new TextEditingController();
  final TextEditingController _nameFilter = new TextEditingController();
  final TextEditingController _emailFilter = new TextEditingController();
  String _login = "";
  String _name = "";
  String _email = "";

  _BodyLayoutState(this.currentUser) {
    _loginFilter.addListener(_loginListen);
    _nameFilter.addListener(_nameListen);
    _emailFilter.addListener(_emailListen);
    _nameFilter.text = currentUser.fullName ?? '';
    _loginFilter.text = currentUser.login ?? '';
    _emailFilter.text = currentUser.email ?? '';
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
            constraints: BoxConstraints(maxWidth: 400),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(60),
              child: Column(
                children: [
                  _buildAvatarFields(),
                  _buildTextFields(),
                  _buildButtons(),
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    child: Visibility(
                      maintainSize: false,
                      maintainAnimation: false,
                      maintainState: false,
                      visible: _isUsersContinues,
                      child: CircularProgressIndicator(
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
    Widget avatarCircle = getUserAvatarWidget(currentUser, 50);

    return new Stack(
      children: <Widget>[
        InkWell(
          splashColor: greyColor2,
          borderRadius: BorderRadius.circular(45),
          onTap: () => _chooseUserImage(),
          child: avatarCircle,
        ),
        new Positioned(
          child: RawMaterialButton(
            onPressed: () {
              _chooseUserImage();
            },
            elevation: 2.0,
            fillColor: Colors.white,
            child: Icon(
              Icons.mode_edit,
              size: 20.0,
            ),
            padding: EdgeInsets.all(5.0),
            shape: CircleBorder(),
          ),
          top: 55.0,
          right: 35.0,
        ),
      ],
    );
  }

  _chooseUserImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    var uploadImageFuture = getUploadingImageFuture(result);

    uploadImageFuture.then((cubeFile) {
      _avatarUrl = cubeFile.getPublicUrl();
      setState(() {
        currentUser.avatar = _avatarUrl;
      });
    }).catchError((exception) {
      _processUpdateUserError(exception);
    });
  }

  Widget _buildTextFields() {
    return Container(
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
              controller: _nameFilter,
              decoration: InputDecoration(labelText: 'Change name'),
            ),
          ),
          Container(
            child: TextField(
              controller: _loginFilter,
              decoration: InputDecoration(labelText: 'Change login'),
            ),
          ),
          Container(
            child: TextField(
              controller: _emailFilter,
              decoration: InputDecoration(labelText: 'Change e-mail'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return new Container(
      child: new Column(
        children: <Widget>[
          SizedBox(
            height: 6,
          ),
          ElevatedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: Size(120, 36),
            ),
            child: new Text('Save'),
            onPressed: _updateUser,
          ),
          SizedBox(
            height: 6,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: Size(160, 36),
            ),
            icon: Icon(
              Icons.logout,
            ),
            label: Text('Logout'),
            onPressed: _logout,
          ),
          SizedBox(
            height: 6,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade300,
              minimumSize: Size(160, 36),
            ),
            icon: Icon(
              Icons.delete,
              color: Colors.red,
            ),
            label: Text(
              'Delete user',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: _deleteUserPressed,
          ),
        ],
      ),
    );
  }

  void _updateUser() {
    print(
        '_updateUser user with login: $_login, name: $_name, e-mail: $_email');
    if (_login.isEmpty &&
        _name.isEmpty &&
        _avatarUrl!.isEmpty &&
        _email.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    var userToUpdate = CubeUser()..id = currentUser.id;

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
    print('_logout $_login and $_name');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want logout current user"),
          actions: <Widget>[
            TextButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
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
                  PushNotificationsManager.instance.unsubscribe();
                  FirebaseAuth.instance.currentUser
                      ?.unlink(PhoneAuthProvider.PROVIDER_ID);
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
    print('_deleteUserPressed ${_login.isNotEmpty ? _login : _email}');
    _userDelete();
  }

  void _userDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete user"),
          content: Text("Are you sure you want to delete current user?"),
          actions: <Widget>[
            TextButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () async {
                CubeChatConnection.instance.destroy();
                await SharedPrefs.instance.deleteUser();

                deleteUser(currentUser.id!).then(
                  (voidValue) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).catchError(
                  (onError) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).whenComplete(() async {
                  await PushNotificationsManager.instance.unsubscribe();
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

  _navigateToLoginScreen(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
  }

  void _processUpdateUserError(exception) {
    log("_processUpdateUserError error $exception", TAG);
    setState(() {
      _isUsersContinues = false;
    });
    showDialogError(exception, context);
  }
}
