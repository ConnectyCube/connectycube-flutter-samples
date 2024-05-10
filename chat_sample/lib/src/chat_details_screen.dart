import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'widgets/common.dart';

class ChatDetailsScreen extends StatelessWidget {
  static const String tag = 'ChatDetailsScreen';
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  const ChatDetailsScreen(this._cubeUser, this._cubeDialog, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
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
                icon: const Icon(
                  Icons.exit_to_app,
                ),
              )
          ],
        ),
        body: _cubeDialog.type == CubeDialogType.PRIVATE
            ? ContactDetailsScreen(_cubeUser, _cubeDialog)
            : GroupDetailsScreen(_cubeUser, _cubeDialog),
    );
  }

  _exitDialog(BuildContext context) {
    log('_exitDialog', tag);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Dialog'),
          content: const Text("Are you sure you want to leave this dialog?"),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                deleteDialog(_cubeDialog.dialogId!).then((onValue) {
                  Fluttertoast.showToast(msg: 'Success');
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil(
                    'select_dialog',
                    (route) => false,
                    arguments: {userArgName: _cubeUser},
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

abstract class DetailScreen extends StatefulWidget {
  static const String tag = "DetailScreen";
  final CubeUser currentUser;
  final CubeDialog cubeDialog;

  const DetailScreen(this.currentUser, this.cubeDialog, {super.key});
}

class ContactDetailsScreen extends DetailScreen {
  const ContactDetailsScreen(super.currentUser, super.cubeDialog, {super.key});

  @override
  State<StatefulWidget> createState() {
    return ContactScreenState();
  }
}

class GroupDetailsScreen extends DetailScreen {
  const GroupDetailsScreen(super.currentUser, super.cubeDialog, {super.key});

  @override
  State<StatefulWidget> createState() {
    return GroupScreenState();
  }
}

abstract class ScreenState extends State<DetailScreen> {
  final Map<int, CubeUser> _occupants = {};
  late CubeDialog _cubeDialog;
  var _isProgressContinues = false;

  @override
  void initState() {
    super.initState();
    _cubeDialog = widget.cubeDialog;

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
    _occupants.remove(widget.currentUser.id);
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

  ContactScreenState() : super();

  @override
  Widget build(BuildContext context) {
    initUser();
    return Scaffold(
      body: Container(
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
                visible: _isProgressContinues,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: <Widget>[getUserAvatarWidget(contactUser!, 50)],
    );
  }

  Widget _buildTextFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.all(50),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(
              right: 10, left: 10,
              bottom: 3, // space between underline and text
            ),
            decoration: const BoxDecoration(
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
              style: const TextStyle(
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
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        ElevatedButton(
          child: const Text(
            'Start dialog',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}

class GroupScreenState extends ScreenState {
  static const String tag = 'GroupScreenState';
  final TextEditingController _nameFilter = TextEditingController();
  String? _photoUrl = "";
  String _name = "";
  final Set<int?> _usersToRemove = {};
  List<int>? _usersToAdd;

  GroupScreenState() : super() {
    _nameFilter.addListener(_nameListen);

    clearFields();
  }

  @override
  void initState() {
    super.initState();

    _nameFilter.text = _cubeDialog.name ?? '';
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    _buildPhotoFields(),
                    _buildTextFields(),
                    _buildGroupFields(),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Visibility(
                        maintainSize: false,
                        maintainAnimation: false,
                        maintainState: false,
                        visible: _isProgressContinues,
                        child: const CircularProgressIndicator(
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
        backgroundColor: Colors.blue,
        onPressed: () => _updateDialog(),
        child: const Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPhotoFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }

    Widget avatarCircle = getDialogAvatarWidget(_cubeDialog, 50);

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
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: <Widget>[
          TextField(
            autofocus: true,
            style: const TextStyle(color: primaryColor, fontSize: 20.0),
            controller: _nameFilter,
            decoration: const InputDecoration(labelText: 'Change group name'),
          ),
        ],
      ),
    );
  }

  _buildGroupFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
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
      padding: const EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: Colors.green, // Text colour here
        width: 2.0, // Underline width
      ))),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          const Text(
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
            icon: const Icon(
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
              icon: const Icon(
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
      return const SizedBox.shrink();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      primary: false,
      itemCount: _occupants.length,
      itemBuilder: _getListItemTile,
      separatorBuilder: (context, index) {
        return const Divider(thickness: 2, indent: 20, endIndent: 20);
      },
    );
  }

  Widget _getListItemTile(BuildContext context, int index) {
    final user = _occupants.values.elementAt(index);
    Widget getUserAvatar() {
      if (user.avatar != null && user.avatar!.isNotEmpty) {
        return getUserAvatarWidget(user, 25);
      } else {
        return const Material(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
          clipBehavior: Clip.hardEdge,
          child: Icon(
            Icons.account_circle,
            size: 50.0,
            color: greyColor,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      child: TextButton(
        child: Row(
          children: <Widget>[
            getUserAvatar(),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 20.0),
                child: Column(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                      child: Text(
                        '${user.fullName}',
                        style: const TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Checkbox(
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
          ],
        ),
        onPressed: () {
          log("user onPressed");
        },
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
    log('_addOpponent', tag);
    _usersToAdd = await Navigator.pushNamed(
      context,
      'search_users',
      arguments: {
        userArgName: widget.currentUser,
      },
    );

    if (_usersToAdd != null && _usersToAdd!.isNotEmpty) _updateDialog();
  }

  _removeOpponent() async {
    log('_removeOpponent', tag);
    if (_usersToRemove.isNotEmpty) _updateDialog();
  }

  void _updateDialog() {
    log('_updateDialog $_name', tag);
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
    if (_usersToAdd?.isNotEmpty ?? false) {
      params['push_all'] = {'occupants_ids': List.of(_usersToAdd!)};
    }
    if (_usersToRemove.isNotEmpty) {
      params['pull_all'] = {'occupants_ids': List.of(_usersToRemove)};
    }

    setState(() {
      _isProgressContinues = true;
    });
    updateDialog(_cubeDialog.dialogId!, params).then((dialog) {
      _cubeDialog = dialog;
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        if ((_usersToAdd?.isNotEmpty ?? false) || (_usersToRemove.isNotEmpty)) {
          initUsers();
        }
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
