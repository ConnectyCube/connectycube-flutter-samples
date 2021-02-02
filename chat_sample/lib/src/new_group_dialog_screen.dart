import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'chat_dialog_screen.dart';
import '../src/utils/api_utils.dart';
import '../src/utils/consts.dart';
import '../src/widgets/common.dart';

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
            'New Group',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
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
  final List<CubeUser> users;

  NewChatScreen(this.currentUser, this._cubeDialog, this.users);

  @override
  State createState() => NewChatScreenState(currentUser, _cubeDialog, users);
}

class NewChatScreenState extends State<NewChatScreen> {
  static const String TAG = "NewChatScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser> users;
  final TextEditingController _nameFilter = new TextEditingController();

  File _image;
  final picker = ImagePicker();

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
      if (_image == null) {
        return Icon(
          Icons.photo_camera,
          size: 45.0,
          color: blueColor,
        );
      } else {
        return Image.file(_image, width: 45.0, height: 45.0);
      }
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
              padding: EdgeInsets.all(10.0),
              shape: CircleBorder(),
            ),
            Flexible(
              child: TextField(
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
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    var image = File(pickedFile.path);
    uploadFile(image, true).then((cubeFile) {
      _image = image;
      var url = cubeFile.getPublicUrl();
      log("_createDialogImage url= $url");
      setState(() {
        _cubeDialog.photo = url;
      });
    }).catchError(_processDialogError);
  }

  _buildDialogOccupants() {
    _getListItemTile(BuildContext context, int index) {
      return Container(
        child: Column(
          children: <Widget>[
            Material(
              child: CircleAvatar(
                backgroundImage: users[index].avatar != null &&
                        users[index].avatar.isNotEmpty
                    ? NetworkImage(users[index].avatar)
                    : null,
                radius: 25,
                child: getAvatarTextWidget(
                    users[index].avatar != null &&
                        users[index].avatar.isNotEmpty,
                    users[index].fullName.substring(0, 2).toUpperCase()),
              ),
              borderRadius: BorderRadius.all(Radius.circular(25.0)),
              clipBehavior: Clip.hardEdge,
            ),
            Container(
              child: Column(
                children: <Widget>[
                  Container(
                    child: Text(
                      users[index].fullName,
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
        itemCount: _cubeDialog.occupantsIds.length,
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

  Future<bool> onBackPress() {
    Navigator.pop(context);
    return Future.value(false);
  }

  _createDialog() {
    log("_createDialog _cubeDialog= $_cubeDialog");
    if (_cubeDialog.name == null || _cubeDialog.name.length < 5) {
      showDialogMsg("Enter more than 4 character", context);
    } else {
      createDialog(_cubeDialog).then((createdDialog) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDialogScreen(currentUser, createdDialog),
          ),
        );
      }).catchError(_processDialogError);
    }
  }
}
