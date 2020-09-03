import '../src/utils/consts.dart';
import '../src/widgets/common.dart';
import 'package:connectycube_sdk/connectycube_chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddOccupantScreen extends StatefulWidget {
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  @override
  State<StatefulWidget> createState() {
    return _AddOccupantScreenState(_cubeUser, _cubeDialog);
  }

  AddOccupantScreen(this._cubeUser, this._cubeDialog);
}

class _AddOccupantScreenState extends State<AddOccupantScreen> {
  static const String TAG = "_AddOccupantScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;

  _AddOccupantScreenState(this.currentUser, this._cubeDialog);

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
            'Contacts',
          ),
        ),
        body: BodyLayout(currentUser, _cubeDialog),
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
  final CubeDialog _cubeDialog;

  BodyLayout(this.currentUser, this._cubeDialog);

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
  String userToSearch;
  String userMsg = " ";

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
        visible: _selectedUsers.isNotEmpty,
        child: FloatingActionButton(
          heroTag: "Update dialog",
          child: Icon(
            Icons.check,
            color: Colors.white,
          ),
          backgroundColor: Colors.blue,
          onPressed: () => _updateDialog(context, _selectedUsers.toList()),
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
                        'Name: ${userList[index].fullName}',
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

  void _updateDialog(BuildContext context, List<int> users) async {
    log("_updateDialog with users= $users");
    Navigator.pop(context, users);
  }
}
