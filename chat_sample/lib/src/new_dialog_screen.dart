import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_chat.dart';

import 'chat_dialog_screen.dart';
import '../src/new_group_dialog_screen.dart';
import '../src/utils/api_utils.dart';
import '../src/utils/consts.dart';
import '../src/widgets/common.dart';

class CreateChatScreen extends StatefulWidget {
  final CubeUser _cubeUser;

  @override
  State<StatefulWidget> createState() {
    return _CreateChatScreenState(_cubeUser);
  }

  CreateChatScreen(this._cubeUser);
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  static const String TAG = "_CreateChatScreenState";
  final CubeUser currentUser;

  _CreateChatScreenState(this.currentUser);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(
            'Logged in as ${currentUser.login}',
          ),
        ),
        body: BodyLayout(currentUser),
      ),
    );
  }

  Future<bool> _onBackPressed(BuildContext context) {
    Navigator.pop(context);
    return Future.value(false);
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
  List<CubeUser> userList = [];
  Set<int> _selectedUsers = {};
  var _isUsersContinues = false;
  var _isPrivateDialog = true;
  String userToSearch;
  String userMsg = " ";

  bool _isDialogContinues = false;

  _BodyLayoutState(this.currentUser);

  _searchUser(value) {
    log("searchUser _user= $value");
    if (value != null)
      setState(() {
        userToSearch = value;
        _isUsersContinues = true;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              _buildTextFields(),
              _buildDialogButton(),
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
              Expanded(
                child: _getUsersList(context),
              ),
            ],
          )),
      floatingActionButton: new Visibility(
        visible: !_isPrivateDialog,
        child: FloatingActionButton(
          heroTag: "New dialog",
          child: Icon(
            Icons.check,
            color: Colors.white,
          ),
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(context, _selectedUsers, true),
        ),
      ),
    );
  }

  Widget _buildTextFields() {
    return new Container(
      child: new Column(
        children: <Widget>[
          new Container(
            child: new TextField(
                textInputAction: TextInputAction.search,
                decoration: new InputDecoration(labelText: 'Search users'),
                onSubmitted: (value) {
                  _searchUser(value.trim());
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton() {
    getIcon() {
      if (_isPrivateDialog) {
        return Icons.person;
      } else {
        return Icons.people;
      }
    }

    getDescription() {
      if (_isPrivateDialog) {
        return "Create group chat";
      } else {
        return "Create private chat";
      }
    }

    return new Container(
      alignment: Alignment.centerLeft,
      child: FlatButton.icon(
        icon: Icon(
          getIcon(),
          size: 25.0,
          color: themeColor,
        ),
        onPressed: () {
          setState(() {
            _isPrivateDialog = !_isPrivateDialog;
          });
        },
        label: Text(getDescription()),
      ),
    );
  }

  Widget _getUsersList(BuildContext context) {
    clearValues() {
      _isUsersContinues = false;
      userToSearch = null;
      userMsg = " ";
      userList.clear();
    }

    if (_isUsersContinues) {
      if (userToSearch != null && userToSearch.isNotEmpty) {
        getUsersByFullName(userToSearch).then((users) {
          log("getusers: $users", TAG);
          setState(() {
            clearValues();
            userList.addAll(users.items);
          });
        }).catchError((onError) {
          log("getusers catchError: $onError", TAG);
          setState(() {
            clearValues();
            userMsg = "Couldn't find user";
          });
        });
      }
    }
    if (userList.isEmpty)
      return FittedBox(
        fit: BoxFit.contain,
        child: Text(userMsg),
      );
    else
      return ListView.builder(
        itemCount: userList.length,
        itemBuilder: _getListItemTile,
      );
  }

  Widget _getListItemTile(BuildContext context, int index) {
    getPrivateWidget() {
      return Container(
        child: FlatButton(
          child: Row(
            children: <Widget>[
              Material(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    backgroundImage: userList[index].avatar != null &&
                            userList[index].avatar.isNotEmpty
                        ? NetworkImage(userList[index].avatar)
                        : null,
                    radius: 25,
                    child: getAvatarTextWidget(
                        userList[index].avatar != null &&
                            userList[index].avatar.isNotEmpty,
                        userList[index].fullName.substring(0, 2).toUpperCase()),
                  ),
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(40.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              Flexible(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Container(
                        child: Text(
                          '${userList[index].fullName}',
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
                child: Icon(
                  Icons.arrow_forward,
                  size: 25.0,
                  color: themeColor,
                ),
              ),
            ],
          ),
          onPressed: () {
            _createDialog(context, {userList[index].id}, false);
          },
          color: greyColor2,
          padding: EdgeInsets.fromLTRB(25.0, 10.0, 25.0, 10.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        margin: EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
      );
    }

    getGroupWidget() {
      return Container(
        child: FlatButton(
          child: Row(
            children: <Widget>[
              Material(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    backgroundImage: userList[index].avatar != null &&
                            userList[index].avatar.isNotEmpty
                        ? NetworkImage(userList[index].avatar)
                        : null,
                    radius: 25,
                    child: getAvatarTextWidget(
                        userList[index].avatar != null &&
                            userList[index].avatar.isNotEmpty,
                        userList[index].fullName.substring(0, 2).toUpperCase()),
                  ),
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(40.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              Flexible(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Container(
                        child: Text(
                          '${userList[index].fullName}',
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
                  value: _selectedUsers.contains(userList[index].id),
                  onChanged: ((checked) {
                    setState(() {
                      if (checked) {
                        _selectedUsers.add(userList[index].id);
                      } else {
                        _selectedUsers.remove(userList[index].id);
                      }
                    });
                  }),
                ),
              ),
            ],
          ),
          onPressed: () {
            setState(() {
              if (_selectedUsers.contains(userList[index].id)) {
                _selectedUsers.remove(userList[index].id);
              } else {
                _selectedUsers.add(userList[index].id);
              }
            });
          },
          color: greyColor2,
          padding: EdgeInsets.fromLTRB(25.0, 10.0, 25.0, 10.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        margin: EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
      );
    }

    getItemWidget() {
      if (_isPrivateDialog) {
        return getPrivateWidget();
      } else {
        return getGroupWidget();
      }
    }

    return getItemWidget();
  }

  void _createDialog(BuildContext context, Set<int> users, bool isGroup) async {
    log("_createDialog with users= $users");
    if (isGroup) {
      CubeDialog newDialog =
          CubeDialog(CubeDialogType.GROUP, occupantsIds: users.toList());
      List<CubeUser> usersToAdd = users
          .map((id) =>
              userList.firstWhere((user) => user.id == id, orElse: () => null))
          .toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              NewGroupDialogScreen(currentUser, newDialog, usersToAdd),
        ),
      );
    } else {
      _isDialogContinues = true;
      CubeDialog newDialog =
          CubeDialog(CubeDialogType.PRIVATE, occupantsIds: users.toList());
      createDialog(newDialog).then((createdDialog) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDialogScreen(currentUser, createdDialog),
          ),
        );
      }).catchError(_processCreateDialogError);
    }
  }

  void _processCreateDialogError(exception) {
    log("Login error $exception", TAG);
    setState(() {
      _isDialogContinues = false;
    });
    showDialogError(exception, context);
  }

  @override
  void initState() {
    super.initState();
    log("initState");
  }
}
