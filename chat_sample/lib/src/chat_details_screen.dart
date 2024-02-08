import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'widgets/common.dart';

class ChatDetailsScreen extends StatelessWidget {
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  ChatDetailsScreen(this._cubeUser, this._cubeDialog);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          automaticallyImplyLeading: false,
          title: Text(
            _cubeDialog.type == CubeDialogType.PRIVATE
                ? "Contact details"
                : "Group details",
          ),
          centerTitle: false,
          actions: <Widget>[
            if (_cubeDialog.type != CubeDialogType.PRIVATE)
              IconButton(
                onPressed: () {
                  _exitDialog(context);
                },
                icon: Icon(
                  Icons.exit_to_app,
                ),
              )
          ],
        ),
        body: DetailScreen(_cubeUser, _cubeDialog),
      ),
    );
  }

  Future<bool> _onBackPressed(BuildContext context) {
    Navigator.pop(context);
    return Future.value(false);
  }

  _exitDialog(BuildContext context) {
    print('_exitDialog');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Leave Dialog'),
          content: Text("Are you sure you want to leave this dialog?"),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                deleteDialog(_cubeDialog.dialogId!).then((onValue) {
                  Fluttertoast.showToast(msg: 'Success');
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil(
                    'select_dialog',
                    (route) => false,
                    arguments: {USER_ARG_NAME: _cubeUser},
                  );
                }).catchError((error) {
                  showDialogError(error, context);
                });
              },
            ),
          ],
        );
      },
    );
  }
}

class DetailScreen extends StatefulWidget {
  static const String TAG = "DetailScreen";
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  DetailScreen(this._cubeUser, this._cubeDialog);

  @override
  State createState() => _cubeDialog.type == CubeDialogType.PRIVATE
      ? ContactScreenState(_cubeUser, _cubeDialog)
      : GroupScreenState(_cubeUser, _cubeDialog);
}

abstract class ScreenState extends State<DetailScreen> {
  final CubeUser _cubeUser;
  CubeDialog _cubeDialog;
  final Map<int, CubeUser> _occupants = Map();
  var _isProgressContinues = false;

  ScreenState(this._cubeUser, this._cubeDialog);

  @override
  void initState() {
    super.initState();
    if (_occupants.isEmpty) {
      initUsers();
    }
  }

  initUsers() async {
    _isProgressContinues = true;
    if (_cubeDialog.occupantsIds == null || _cubeDialog.occupantsIds!.isEmpty) {
      setState(() {
        _isProgressContinues = false;
      });
      return;
    }

    var result = await getUsersByIds(_cubeDialog.occupantsIds!.toSet());
    _occupants.clear();
    _occupants.addAll(result);
    _occupants.remove(_cubeUser.id);
    setState(() {
      _isProgressContinues = false;
    });
  }
}

class ContactScreenState extends ScreenState {
  CubeUser? contactUser;

  initUser() {
    contactUser = _occupants.values.isNotEmpty
        ? _occupants.values.first
        : CubeUser(fullName: "Absent");
  }

  ContactScreenState(_cubeUser, _cubeDialog) : super(_cubeUser, _cubeDialog);

  @override
  Widget build(BuildContext context) {
    initUser();
    return Scaffold(
      body: Container(
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
                  visible: _isProgressContinues,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildAvatarFields() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return Stack(
      children: <Widget>[getUserAvatarWidget(contactUser!, 50)],
    );
  }

  Widget _buildTextFields() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return Container(
      margin: EdgeInsets.all(50),
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(
              right: 10, left: 10,
              bottom: 3, // space between underline and text
            ),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
              color: primaryColor, // Text colour here
              width: 1.0, // Underline width
            ))),
            child: Text(
              contactUser!.fullName ??
                  contactUser!.login ??
                  contactUser!.email ??
                  '',
              style: TextStyle(
                color: primaryColor,
                fontSize: 20, // Text colour here
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildButtons() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return new Container(
      child: new Column(
        children: <Widget>[
          new ElevatedButton(
            child: Text(
              'Start dialog',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }
}

class GroupScreenState extends ScreenState {
  final TextEditingController _nameFilter = new TextEditingController();
  String? _photoUrl = "";
  String _name = "";
  Set<int?> _usersToRemove = {};
  List<int>? _usersToAdd;

  GroupScreenState(_cubeUser, _cubeDialog) : super(_cubeUser, _cubeDialog) {
    _nameFilter.addListener(_nameListen);
    _nameFilter.text = _cubeDialog.name;
    clearFields();
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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    _buildPhotoFields(),
                    _buildTextFields(),
                    _buildGroupFields(),
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      child: Visibility(
                        maintainSize: false,
                        maintainAnimation: false,
                        maintainState: false,
                        visible: _isProgressContinues,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ],
                )),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "Update dialog",
        child: Icon(
          Icons.check,
          color: Colors.white,
        ),
        backgroundColor: Colors.blue,
        onPressed: () => _updateDialog(),
      ),
    );
  }

  Widget _buildPhotoFields() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }

    Widget avatarCircle = getDialogAvatarWidget(_cubeDialog, 50);

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
      _photoUrl = cubeFile.getPublicUrl();
      setState(() {
        _cubeDialog.photo = _photoUrl;
      });
    }).catchError((error) {
      _processUpdateError(error);
    });
  }

  Widget _buildTextFields() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
              autofocus: true,
              style: TextStyle(color: primaryColor, fontSize: 20.0),
              controller: _nameFilter,
              decoration: InputDecoration(labelText: 'Change group name'),
            ),
          ),
        ],
      ),
    );
  }

  _buildGroupFields() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        _addMemberBtn(),
        _getUsersList(),
      ],
    );
  }

  Widget _addMemberBtn() {
    return Container(
      padding: EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: Colors.green, // Text colour here
        width: 2.0, // Underline width
      ))),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            'Members:',
            style: TextStyle(
              color: primaryColor,
              fontSize: 18, // Text colour here
            ),
          ),
          Expanded(flex: 1, child: Container()),
          IconButton(
            onPressed: () {
              _addOpponent();
            },
            icon: Icon(
              Icons.person_add,
              size: 26.0,
              color: Colors.green,
            ),
          ),
          Visibility(
            visible: _usersToRemove.isNotEmpty,
            child: IconButton(
              onPressed: () {
                _removeOpponent();
              },
              icon: Icon(
                Icons.person_remove,
                size: 26.0,
                color: Colors.red,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _getUsersList() {
    if (_isProgressContinues) {
      return SizedBox.shrink();
    }
    return ListView.separated(
      padding: EdgeInsets.only(top: 8),
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      primary: false,
      itemCount: _occupants.length,
      itemBuilder: _getListItemTile,
      separatorBuilder: (context, index) {
        return Divider(thickness: 2, indent: 20, endIndent: 20);
      },
    );
  }

  Widget _getListItemTile(BuildContext context, int index) {
    final user = _occupants.values.elementAt(index);
    Widget getUserAvatar() {
      if (user.avatar != null && user.avatar!.isNotEmpty) {
        return getUserAvatarWidget(user, 25);
      } else {
        return Material(
          child: Icon(
            Icons.account_circle,
            size: 50.0,
            color: greyColor,
          ),
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
          clipBehavior: Clip.hardEdge,
        );
      }
    }

    return Container(
      child: TextButton(
        child: Row(
          children: <Widget>[
            getUserAvatar(),
            Flexible(
              child: Container(
                child: Column(
                  children: <Widget>[
                    Container(
                      child: Text(
                        '${user.fullName}',
                        style: TextStyle(color: primaryColor),
                      ),
                      alignment: Alignment.centerLeft,
                      margin: EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                    ),
                  ],
                ),
                margin: EdgeInsets.only(left: 20.0),
              ),
            ),
            Container(
              child: Checkbox(
                value: _usersToRemove
                    .contains(_occupants.values.elementAt(index).id),
                onChanged: ((checked) {
                  setState(() {
                    if (checked!) {
                      _usersToRemove.add(_occupants.values.elementAt(index).id);
                    } else {
                      _usersToRemove
                          .remove(_occupants.values.elementAt(index).id);
                    }
                  });
                }),
              ),
            ),
          ],
        ),
        onPressed: () {
          log("user onPressed");
        },
      ),
      margin: EdgeInsets.only(bottom: 10.0),
    );
  }

  void _processUpdateError(exception) {
    log("_processUpdateUserError error $exception");
    setState(() {
      clearFields();
      _isProgressContinues = false;
    });
    showDialogError(exception, context);
  }

  _addOpponent() async {
    print('_addOpponent');
    _usersToAdd = await Navigator.pushNamed(
      context,
      'search_users',
      arguments: {
        USER_ARG_NAME: _cubeUser,
      },
    );

    if (_usersToAdd != null && _usersToAdd!.isNotEmpty) _updateDialog();
  }

  _removeOpponent() async {
    print('_removeOpponent');
    if (_usersToRemove.isNotEmpty) _updateDialog();
  }

  void _updateDialog() {
    print('_updateDialog $_name');
    if (_name.isEmpty &&
        _photoUrl!.isEmpty &&
        (_usersToAdd?.isEmpty ?? true) &&
        (_usersToRemove.isEmpty)) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    Map<String, dynamic> params = {};
    if (_name.isNotEmpty) params['name'] = _name;
    if (_photoUrl!.isNotEmpty) params['photo'] = _photoUrl;
    if (_usersToAdd?.isNotEmpty ?? false)
      params['push_all'] = {'occupants_ids': List.of(_usersToAdd!)};
    if (_usersToRemove.isNotEmpty)
      params['pull_all'] = {'occupants_ids': List.of(_usersToRemove)};

    setState(() {
      _isProgressContinues = true;
    });
    updateDialog(_cubeDialog.dialogId!, params).then((dialog) {
      _cubeDialog = dialog;
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        if ((_usersToAdd?.isNotEmpty ?? false) || (_usersToRemove.isNotEmpty))
          initUsers();
        _isProgressContinues = false;
        clearFields();
      });
    }).catchError((error) {
      _processUpdateError(error);
    });
  }

  clearFields() {
    _name = '';
    _photoUrl = '';
    _usersToAdd = null;
    _usersToRemove.clear();
  }
}
