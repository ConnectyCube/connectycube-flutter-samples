import 'package:chat_sample/src/managers/chat_manager.dart';
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

  const NewGroupDialogScreen(this.currentUser, this._cubeDialog, this.users,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Group configuration...',
          ),
          centerTitle: true,
        ),
        body: NewChatScreen(currentUser, _cubeDialog, users),
        resizeToAvoidBottomInset: false);
  }
}

class NewChatScreen extends StatefulWidget {
  static const String tag = "_CreateChatScreenState";
  final CubeUser currentUser;
  final CubeDialog cubeDialog;
  final List<CubeUser?> users;

  const NewChatScreen(this.currentUser, this.cubeDialog, this.users,
      {super.key});

  @override
  State createState() => NewChatScreenState();
}

class NewChatScreenState extends State<NewChatScreen> {
  static const String tag = "NewChatScreenState";

  final TextEditingController _nameFilter = TextEditingController();

  NewChatScreenState();

  @override
  void initState() {
    super.initState();
    _nameFilter.addListener(_nameListener);
  }

  void _nameListener() {
    if (_nameFilter.text.length > 4) {
      log("_createDialogImage text= ${_nameFilter.text.trim()}");
      widget.cubeDialog.name = _nameFilter.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGroupFields(),
                _buildDialogOccupants(),
              ],
            )),
        floatingActionButton: FloatingActionButton(
          heroTag: "New dialog",
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(),
          child: const Icon(
            Icons.check,
            color: Colors.white,
          ),
        ),
        resizeToAvoidBottomInset: false);
  }

  _buildGroupFields() {
    getIcon() {
      return getDialogAvatarWidget(widget.cubeDialog, 45,
          placeholder: const Icon(
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
              padding: const EdgeInsets.all(0),
              shape: const CircleBorder(),
              child: getIcon(),
            ),
            const SizedBox(
              width: 16,
            ),
            Flexible(
              child: TextField(
                autofocus: true,
                controller: _nameFilter,
                decoration: const InputDecoration(labelText: 'Group Name...'),
              ),
            )
          ],
        ),
        Container(
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.all(16.0),
          child: const Text(
            'Please provide a group name and an optional group icon',
            style: TextStyle(color: primaryColor),
          ),
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
        widget.cubeDialog.photo = url;
      });
    }).catchError((exception) {
      _processDialogError(exception);
    });
  }

  _buildDialogOccupants() {
    getListItemTile(BuildContext context, int index) {
      return Column(
        children: <Widget>[
          getUserAvatarWidget(widget.users[index]!, 25),
          Container(
            margin: const EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 10.0),
            child: Column(
              children: <Widget>[
                Container(
                  width: MediaQuery.of(context).size.width / 4,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 5.0),
                  child: Text(
                    widget.users[index]!.fullName ??
                        widget.users[index]!.login ??
                        widget.users[index]!.email ??
                        '???',
                    style: const TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    getOccupants() {
      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        scrollDirection: Axis.horizontal,
        itemCount: widget.cubeDialog.occupantsIds!.length,
        itemBuilder: getListItemTile,
      );
    }

    return Expanded(
      child: getOccupants(),
    );
  }

  void _processDialogError(exception) {
    log("error $exception", tag);
    showDialogError(exception, context);
  }

  _createDialog() {
    log("_createDialog _cubeDialog= $widget.cubeDialog");
    if (widget.cubeDialog.name == null || widget.cubeDialog.name!.length < 5) {
      showDialogMsg("Enter more than 4 character", context);
    } else {
      createDialog(widget.cubeDialog).then((createdDialog) {
        ChatManager.instance.addDialogController.add(createdDialog);

        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            'chat_dialog', (route) => route.isFirst, arguments: {
          userArgName: widget.currentUser,
          dialogArgName: createdDialog
        });
      }).catchError((exception) {
        _processDialogError(exception);
      });
    }
  }
}
