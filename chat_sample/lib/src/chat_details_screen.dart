import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'add_occupant_screen.dart';
import '../src/utils/api_utils.dart';
import '../src/utils/consts.dart';
import '../src/widgets/common.dart';

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
          title: Text(
            _cubeDialog.type == CubeDialogType.PRIVATE
                ? "Contact details"
                : "Group details",
          ),
          centerTitle: false,
          actions: <Widget>[],
        ),
        body: DetailScreen(_cubeUser, _cubeDialog),
      ),
    );
  }

  Future<bool> _onBackPressed(BuildContext context) {
    Navigator.pop(context);
    return Future.value(false);
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
      children: <Widget>[
        CircleAvatar(
          backgroundImage:
              contactUser!.avatar != null && contactUser!.avatar!.isNotEmpty
                  ? NetworkImage(contactUser!.avatar!)
                  : null,
          backgroundColor: greyColor2,
          radius: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
            child: Text(
              contactUser!.fullName!.substring(0, 2).toUpperCase(),
              style: TextStyle(fontSize: 40),
            ),
          ),
        ),
      ],
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
              contactUser!.fullName!,
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
                fontSize: 20, // Text colour here
              ),
            ),
            onPressed: () => Navigator.pop(context),
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
    Widget avatarCircle = CircleAvatar(
      backgroundImage:
          _cubeDialog.photo != null && _cubeDialog.photo!.isNotEmpty
              ? NetworkImage(_cubeDialog.photo!)
              : null,
      backgroundColor: greyColor2,
      radius: 50,
      child: getAvatarTextWidget(
          _cubeDialog.photo != null && _cubeDialog.photo!.isNotEmpty,
          _cubeDialog.name!.substring(0, 2).toUpperCase()),
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
      padding: EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
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
        _removeMemberBtn(),
        _getUsersList(),
        _exitGroupBtn(),
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
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _addOpponent(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Icon(
              Icons.person_add,
              size: 35.0,
              color: blueColor,
            ),
            Padding(
              child: Text(
                'Add member',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
              padding: EdgeInsets.only(left: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removeMemberBtn() {
    if (_usersToRemove.isEmpty) {
      return SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _removeOpponent(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.person_outline,
                size: 35.0,
                color: blueColor,
              ),
            ),
            Padding(
              child: Text(
                'Remove member',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
              padding: EdgeInsets.only(left: 12),
            ),
          ],
        ),
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
        return CircleAvatar(
          backgroundImage: NetworkImage(user.avatar!),
          backgroundColor: greyColor2,
          radius: 25.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
          ),
        );
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

  Widget _exitGroupBtn() {
    return Container(
      padding: EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _exitDialog(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Icon(
              Icons.exit_to_app,
              size: 35.0,
              color: blueColor,
            ),
            Padding(
              child: Text(
                'Exit group member',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
              padding: EdgeInsets.only(left: 16),
            ),
          ],
        ),
      ),
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
    _usersToAdd = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOccupantScreen(_cubeUser),
      ),
    );
    if (_usersToAdd != null && _usersToAdd!.isNotEmpty) _updateDialog();
  }

  _removeOpponent() async {
    print('_removeOpponent');
    if (_usersToRemove.isNotEmpty) _updateDialog();
  }

  _exitDialog() {
    print('_exitDialog');
    deleteDialog(_cubeDialog.dialogId!).then((onValue) {
      Fluttertoast.showToast(msg: 'Success');
      Navigator.pushReplacementNamed(context, 'select_dialog',
          arguments: {USER_ARG_NAME: _cubeUser});
    }).catchError((error) {
      _processUpdateError(error);
    });
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
