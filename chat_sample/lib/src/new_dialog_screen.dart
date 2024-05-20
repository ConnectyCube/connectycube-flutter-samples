import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_chat.dart';

import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'widgets/common.dart';

class CreateChatScreen extends StatelessWidget {
  final CubeUser _cubeUser;

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
        title: const Text(
          'Search users...',
        ),
      ),
      body: BodyLayout(_cubeUser),
    );
  }

  const CreateChatScreen(this._cubeUser, {super.key});
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

  List<CubeUser> userList = [];
  final Set<int> _selectedUsers = {};
  var _isUsersContinues = false;
  var _isPrivateDialog = true;
  String? userToSearch;
  String userMsg = " ";

  _BodyLayoutState();

  _searchUser(value) {
    log("searchUser _user= $value");
    if (value != null) {
      setState(() {
        userToSearch = value;
        _isUsersContinues = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              _buildTextFields(),
              _buildDialogButton(),
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
              Expanded(
                child: _getUsersList(context),
              ),
            ],
          )),
      floatingActionButton: Visibility(
        visible: !_isPrivateDialog,
        child: FloatingActionButton(
          heroTag: "New dialog",
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(context, _selectedUsers, true),
          child: const Icon(
            Icons.check,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: <Widget>[
        TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(labelText: 'Search users'),
            onSubmitted: (value) {
              _searchUser(value.trim());
            }),
      ],
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

    return Container(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
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
      if (userToSearch != null && userToSearch!.isNotEmpty) {
        getUsersByFullName(userToSearch!).then((users) {
          log("getUsers: $users", tag);
          setState(() {
            clearValues();
            userList.addAll(users!.items);
          });
        }).catchError((onError) {
          log("getUsers catchError: $onError", tag);
          setState(() {
            clearValues();
            userMsg = "Couldn't find user";
          });
        });
      }
    }
    if (userList.isEmpty) {
      return FittedBox(
        fit: BoxFit.contain,
        child: Text(userMsg),
      );
    } else {
      return ListView.builder(
        itemCount: userList.length,
        itemBuilder: _getListItemTile,
      );
    }
  }

  Widget _getListItemTile(BuildContext context, int index) {
    getPrivateWidget() {
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
        child: TextButton(
          child: Row(
            children: <Widget>[
              getUserAvatarWidget(userList[index], 30),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    children: <Widget>[
                      Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                        child: Text(
                          '${userList[index].fullName}',
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 25.0,
                color: themeColor,
              ),
            ],
          ),
          onPressed: () {
            _createDialog(context, {userList[index].id!}, false);
          },
        ),
      );
    }

    getGroupWidget() {
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
        child: TextButton(
          child: Row(
            children: <Widget>[
              getUserAvatarWidget(userList[index], 30),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    children: <Widget>[
                      Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                        child: Text(
                          '${userList[index].fullName}',
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Checkbox(
                value: _selectedUsers.contains(userList[index].id),
                onChanged: ((checked) {
                  setState(() {
                    if (checked!) {
                      _selectedUsers.add(userList[index].id!);
                    } else {
                      _selectedUsers.remove(userList[index].id);
                    }
                  });
                }),
              ),
            ],
          ),
          onPressed: () {
            setState(() {
              if (_selectedUsers.contains(userList[index].id)) {
                _selectedUsers.remove(userList[index].id);
              } else {
                _selectedUsers.add(userList[index].id!);
              }
            });
          },
        ),
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
          .map((id) => userList.firstWhere((user) => user.id == id))
          .toList();

      Navigator.of(context).pushNamed('configure_group_dialog', arguments: {
        userArgName: widget.currentUser,
        dialogArgName: newDialog,
        selectedUsersArgName: usersToAdd,
      });
    } else {
      CubeDialog newDialog =
          CubeDialog(CubeDialogType.PRIVATE, occupantsIds: users.toList());
      createDialog(newDialog).then((createdDialog) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            'chat_dialog', (route) => false, arguments: {
          userArgName: widget.currentUser,
          dialogArgName: createdDialog
        });
      }).catchError((error) {
        _processCreateDialogError(error);
      });
    }
  }

  void _processCreateDialogError(exception) {
    log("Login error $exception", tag);
    showDialogError(exception, context);
  }

  @override
  void initState() {
    super.initState();
    log("initState");
  }
}
