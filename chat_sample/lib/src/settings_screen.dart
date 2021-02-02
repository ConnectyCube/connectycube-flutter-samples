import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../src/push_notifications_manager.dart';
import '../src/utils/api_utils.dart';
import '../src/utils/consts.dart';
import '../src/utils/pref_util.dart';
import '../src/widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  final CubeUser currentUser;

  SettingsScreen(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
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
  String _avatarUrl = "";
  final picker = ImagePicker();
  final TextEditingController _loginFilter = new TextEditingController();
  final TextEditingController _nameFilter = new TextEditingController();
  String _login = "";
  String _name = "";

  _BodyLayoutState(this.currentUser) {
    _loginFilter.addListener(_loginListen);
    _nameFilter.addListener(_nameListen);
    _nameFilter.text = currentUser.fullName;
    _loginFilter.text = currentUser.login;
  }

  _searchUser(value) {
    log("searchUser _user= $value");
    if (value != null)
      setState(() {
        _isUsersContinues = true;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
            )),
      ),
    );
  }

  Widget _buildAvatarFields() {
    Widget avatarCircle = CircleAvatar(
      backgroundImage:
          currentUser.avatar != null && currentUser.avatar.isNotEmpty
              ? NetworkImage(currentUser.avatar)
              : null,
      backgroundColor: greyColor2,
      radius: 50,
      child: getAvatarTextWidget(
        currentUser.avatar != null && currentUser.avatar.isNotEmpty,
        currentUser.fullName.substring(0, 2).toUpperCase(),
      ),
    );

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
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    var image = File(pickedFile.path);
    uploadFile(image, true).then((cubeFile) {
      _avatarUrl = cubeFile.getPublicUrl();
      setState(() {
        currentUser.avatar = _avatarUrl;
      });
    }).catchError(_processUpdateUserError);
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
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return new Container(
      child: new Column(
        children: <Widget>[
          new FlatButton(
            child: new Text('Save'),
            onPressed: _updateUser,
          ),
          new RaisedButton(
            child: new Text('Logout'),
            onPressed: _logout,
          )
        ],
      ),
    );
  }

  void _updateUser() {
    print('_updateUser user with $_login and $_name');
    if (_login.isEmpty && _name.isEmpty && _avatarUrl.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    var userToUpdate = CubeUser()..id = currentUser.id;

    if (_name.isNotEmpty) userToUpdate.fullName = _name;
    if (_login.isNotEmpty) userToUpdate.login = _login;
    if (_avatarUrl.isNotEmpty) userToUpdate.avatar = _avatarUrl;
    setState(() {
      _isUsersContinues = true;
    });
    updateUser(userToUpdate).then((user) {
      SharedPrefs.instance.updateUser(user);
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        _isUsersContinues = false;
      });
    }).catchError(_processUpdateUserError);
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
            FlatButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            FlatButton(
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
