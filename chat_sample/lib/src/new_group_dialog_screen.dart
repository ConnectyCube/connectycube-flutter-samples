import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'widgets/common.dart';

class NewGroupDialogScreen extends StatelessWidget {
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser> users;

  NewGroupDialogScreen(this.currentUser, this._cubeDialog, this.users);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Group configuration...',
          ),
          centerTitle: true,
        ),
        body: NewChatScreen(currentUser, _cubeDialog, users),
        resizeToAvoidBottomInset: false);
  }
}

class NewChatScreen extends StatefulWidget {
  static const String TAG = "_CreateChatScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser?> users;

  NewChatScreen(this.currentUser, this._cubeDialog, this.users);

  @override
  State createState() => NewChatScreenState(currentUser, _cubeDialog, users);
}

class NewChatScreenState extends State<NewChatScreen> {
  static const String TAG = "NewChatScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser?> users;
  final TextEditingController _nameFilter = new TextEditingController();

  NewChatScreenState(this.currentUser, this._cubeDialog, this.users);

  @override
  void initState() {
    super.initState();
    _nameFilter.addListener(_nameListener);
  }

  void _nameListener() {
    if (_nameFilter.text.length > 4) {
      log("_createDialogImage text= ${_nameFilter.text.trim()}");
      _cubeDialog.name = _nameFilter.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGroupFields(),
                _buildDialogOccupants(),
              ],
            )),
        floatingActionButton: FloatingActionButton(
          heroTag: "New dialog",
          child: Icon(
            Icons.check,
            color: Colors.white,
          ),
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(),
        ),
        resizeToAvoidBottomInset: false);
  }

  _buildGroupFields() {
    getIcon() {
      return getDialogAvatarWidget(_cubeDialog, 45,
          placeholder: Icon(
            Icons.add_a_photo,
            size: 45.0,
            color: blueColor,
          ));
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            RawMaterialButton(
              onPressed: () => _createDialogImage(),
              elevation: 2.0,
              fillColor: Colors.white,
              child: getIcon(),
              padding: EdgeInsets.all(0),
              shape: CircleBorder(),
            ),
            SizedBox(
              width: 16,
            ),
            Flexible(
              child: TextField(
                autofocus: true,
                controller: _nameFilter,
                decoration: InputDecoration(labelText: 'Group Name...'),
              ),
            )
          ],
        ),
        Container(
          child: Text(
            'Please provide a group name and an optional group icon',
            style: TextStyle(color: primaryColor),
          ),
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.all(16.0),
        ),
      ],
    );
  }

  _createDialogImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    var uploadImageFuture = getUploadingMediaFuture(result);

    uploadImageFuture.then((cubeFile) {
      var url = cubeFile.getPublicUrl();
      log("_createDialogImage url= $url");
      setState(() {
        _cubeDialog.photo = url;
      });
    }).catchError((exception) {
      _processDialogError(exception);
    });
  }

  _buildDialogOccupants() {
    _getListItemTile(BuildContext context, int index) {
      return Container(
        child: Column(
          children: <Widget>[
            getUserAvatarWidget(users[index]!, 25),
            Container(
              child: Column(
                children: <Widget>[
                  Container(
                    child: Text(
                      users[index]!.fullName ??
                          users[index]!.login ??
                          users[index]!.email ??
                          '???',
                      style: TextStyle(color: primaryColor),
                    ),
                    width: MediaQuery.of(context).size.width / 4,
                    alignment: Alignment.center,
                    margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 5.0),
                  ),
                ],
              ),
              margin: EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 10.0),
            ),
          ],
        ),
      );
    }

    _getOccupants() {
      return ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 20.0),
        scrollDirection: Axis.horizontal,
        itemCount: _cubeDialog.occupantsIds!.length,
        itemBuilder: _getListItemTile,
      );
    }

    return Container(
      child: Expanded(
        child: _getOccupants(),
      ),
    );
  }

  void _processDialogError(exception) {
    log("error $exception", TAG);
    showDialogError(exception, context);
  }

  _createDialog() {
    log("_createDialog _cubeDialog= $_cubeDialog");
    if (_cubeDialog.name == null || _cubeDialog.name!.length < 5) {
      showDialogMsg("Enter more than 4 character", context);
    } else {
      createDialog(_cubeDialog).then((createdDialog) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            'chat_dialog', (route) => false, arguments: {
          USER_ARG_NAME: currentUser,
          DIALOG_ARG_NAME: createdDialog
        });
      }).catchError((exception) {
        _processDialogError(exception);
      });
    }
  }
}
